<script lang="ts">
	import type { Message } from "$lib/types/Message";
	import { createEventDispatcher, onDestroy, tick } from "svelte";

	import CarbonSendAltFilled from "~icons/carbon/send-alt-filled";
	import CarbonExport from "~icons/carbon/export";
	import CarbonStopFilledAlt from "~icons/carbon/stop-filled-alt";
	import CarbonClose from "~icons/carbon/close";
	import CarbonCheckmark from "~icons/carbon/checkmark";
	import CarbonCaretDown from "~icons/carbon/caret-down";

	import EosIconsLoading from "~icons/eos-icons/loading";

	import ChatInput from "./ChatInput.svelte";
	import StopGeneratingBtn from "../StopGeneratingBtn.svelte";
	import type { Model } from "$lib/types/Model";
	import WebSearchToggle from "../WebSearchToggle.svelte";
	import LoginModal from "../LoginModal.svelte";
	import { page } from "$app/stores";
	import FileDropzone from "./FileDropzone.svelte";
	import RetryBtn from "../RetryBtn.svelte";
	import UploadBtn from "../UploadBtn.svelte";
	import file2base64 from "$lib/utils/file2base64";
	import type { Assistant } from "$lib/types/Assistant";
	import { base } from "$app/paths";
	import ContinueBtn from "../ContinueBtn.svelte";
	import AssistantIntroduction from "./AssistantIntroduction.svelte";
	import ChatMessage from "./ChatMessage.svelte";
	import ScrollToBottomBtn from "../ScrollToBottomBtn.svelte";
	import { browser } from "$app/environment";
	import { snapScrollToBottom } from "$lib/actions/snapScrollToBottom";
	import SystemPromptModal from "../SystemPromptModal.svelte";
	import ChatIntroduction from "./ChatIntroduction.svelte";
	import { useConvTreeStore } from "$lib/stores/convTree";

	export let messages: Message[] = [];
	export let loading = false;
	export let pending = false;

	export let shared = false;
	export let currentModel: Model;
	export let models: Model[];
	export let assistant: Assistant | undefined = undefined;
	export let preprompt: string | undefined = undefined;
	export let files: File[] = [];

	$: isReadOnly = !models.some((model) => model.id === currentModel.id);

	let loginModalOpen = false;
	let message: string;
	let timeout: ReturnType<typeof setTimeout>;
	let isSharedRecently = false;
	$: $page.params.id && (isSharedRecently = false);

	const dispatch = createEventDispatcher<{
		message: string;
		share: void;
		stop: void;
		retry: { id: Message["id"]; content?: string };
		continue: { id: Message["id"] };
	}>();

	const handleSubmit = () => {
		if (loading) return;

		if (hasListened) {
			dispatch("message", outputText);
			outputText = "";
		} else {
			dispatch("message", message);
			message = "";
		}
	};

	let lastTarget: EventTarget | null = null;

	let onDrag = false;

	const onDragEnter = (e: DragEvent) => {
		lastTarget = e.target;
		onDrag = true;
	};
	const onDragLeave = (e: DragEvent) => {
		if (e.target === lastTarget) {
			onDrag = false;
		}
	};
	const onDragOver = (e: DragEvent) => {
		e.preventDefault();
	};

	const convTreeStore = useConvTreeStore();

	$: lastMessage = browser && (messages.find((m) => m.id == $convTreeStore.leaf) as Message);
	$: lastIsError =
		lastMessage &&
		!loading &&
		(lastMessage.from === "user" ||
			lastMessage.updates?.findIndex((u) => u.type === "status" && u.status === "error") !== -1);

	$: sources = files.map((file) => file2base64(file));
	// Explicitly subscribe to the page store
	$: $page, extractConversationId(), fetchKnowledge(conversationId);

	function updateCurrentPageURL() {
		if (browser) {
			currentPageURL = window.location.href;
			console.log("in func updateCurrentPageURL, currentPageUrl = " + currentPageURL)
		}
	}

	function onShare() {
		dispatch("share");
		isSharedRecently = true;
		if (timeout) {
			clearTimeout(timeout);
		}
		timeout = setTimeout(() => {
			isSharedRecently = false;
		}, 2000);
	}

	let outputText = "Click the button to start listening...";
	let isListening = false;
	let hasListened = false;

	function runSpeechRecog() {
		outputText = "Listening...";
		isListening = true;

		let recognition = new webkitSpeechRecognition();

		recognition.onresult = (e) => {
			let transcript = e.results[0][0].transcript;
			outputText = transcript;
			console.log(outputText);
			recognition.stop();
			isListening = false;
			hasListened = true;
		};

		recognition.onerror = (e) => {
			outputText = "Error occurred during recognition. Please try again.";
			isListening = false;
			hasListened = false;
		};

		recognition.start();
	}

	onDestroy(() => {
		if (timeout) {
			clearTimeout(timeout);
		}
	});

	let chatContainer: HTMLElement;

	async function scrollToBottom() {
		await tick();
		chatContainer.scrollTop = chatContainer.scrollHeight;
	}

	// If last message is from user, scroll to bottom
	$: if (lastMessage && lastMessage.from === "user") {
		scrollToBottom();
	}

	let knowledgeBaseContent = "";
	let currentPageURL = '';
	let conversationId = '';

	async function fetchKnowledge(conversationId: string | number | boolean) {
		if (browser) {
			if(conversationId === ""){
				conversationId = "default";
			}
			const url = `http://127.0.0.1:8000/knowledge?conversationId=${encodeURIComponent(conversationId)}`;
			try {
			const response = await fetch(url, {
				method: 'GET',
				headers: {
					'Accept': 'application/json',
				},
			});
			if (!response.ok) {
				if(response.status === 404){
					console.log("No knowledge base content found for this conversation");
					knowledgeBaseContent = "";
					return;
				} else {
					throw new Error(`HTTP error! status: ${response.status}`);
				}
			}
			const data = await response.json();
			console.log("Knowledge fetched:", data);
			// Process your data here
			knowledgeBaseContent = data.content;
			} catch (error) {
				console.error("Error fetching knowledge base content:", error);
				knowledgeBaseContent = "";
			}
		}
	}

	function extractConversationId() {
		if (browser) {
			currentPageURL = window.location.href;
			const url = new URL(currentPageURL);
			const pathSegments = url.pathname.split('/').filter(Boolean);
			// URL structure is like "/conversation/<conversation-id>"
			const conversationIndex = pathSegments.findIndex(segment => segment === 'conversation');
			if (conversationIndex !== -1 && pathSegments.length > conversationIndex + 1) {
				conversationId = pathSegments[conversationIndex + 1];
				// This will extract the conversation ID or the next part of the URL path
				console.log("conversationId = " + conversationId);
			}
		}
	}

	async function saveKnowledgeBaseContent() {
		try {
			// const rootMessageId = lastMessage && lastMessage.ancestors ? lastMessage.ancestors[0] : (lastMessage ? lastMessage.id : null);
			if (conversationId ===  ""){
				conversationId = "default";
			}
			const response = await fetch("http://127.0.0.1:8000/knowledge", {
				method: "POST",
				headers: {
				"Content-Type": "application/json",
				},
				body: JSON.stringify(
					{
						conversationId,
						content: knowledgeBaseContent
					}
				),
			});
		const data = await response.json();
		console.log("Knowledge base content saved:", data);
		} catch (error) {
		console.error("Error saving knowledge base content:", error);
		}
  	}
</script>

<div class="relative min-h-0 min-w-0">
	{#if loginModalOpen}
		<LoginModal
			on:close={() => {
				loginModalOpen = false;
			}}
		/>
	{/if}
	<div
		class="scrollbar-custom mr-1 h-full overflow-y-auto"
		use:snapScrollToBottom={messages.length ? [...messages] : false}
		bind:this={chatContainer}
	>
		<!-- Flex container for content and sidebar -->
		<div class="flex h-full">
			<!-- Main content container -->
			<div
				class="scrollbar-custom mr-1 h-full flex-1 overflow-y-auto"
				use:snapScrollToBottom={messages.length ? [...messages] : false}
				bind:this={chatContainer}
			>
				<div class="mx-auto flex h-full max-w-3xl flex-col gap-6 px-5 pt-6 sm:gap-8 xl:flex-1">
					<!-- Existing content goes here -->
					<div class="mx-auto flex h-full max-w-3xl flex-col gap-6 px-5 pt-6 sm:gap-8 xl:max-w-4xl">
						{#if $page.data?.assistant && !!messages.length}
							<a
								class="mx-auto flex items-center gap-1.5 rounded-full border border-gray-100 bg-gray-50 py-1 pl-1 pr-3 text-sm text-gray-800 hover:bg-gray-100 dark:border-gray-800 dark:bg-gray-800 dark:text-gray-200 dark:hover:bg-gray-700"
								href="{base}/settings/assistants/{$page.data.assistant._id}"
							>
								{#if $page.data?.assistant.avatar}
									<img
										src="{base}/settings/assistants/{$page.data?.assistant._id.toString()}/avatar.jpg?hash=${$page
											.data.assistant.avatar}"
										alt="Avatar"
										class="size-5 rounded-full object-cover"
									/>
								{:else}
									<div
										class="size-6 flex items-center justify-center rounded-full bg-gray-300 font-bold uppercase text-gray-500"
									>
										{$page.data?.assistant.name[0]}
									</div>
								{/if}

								{$page.data.assistant.name}
							</a>
						{:else if preprompt && preprompt != currentModel.preprompt}
							<SystemPromptModal preprompt={preprompt ?? ""} />
						{/if}

						{#if messages.length > 0}
							<div class="flex h-max flex-col gap-6 pb-52">
								<ChatMessage
									{loading}
									{messages}
									id={messages[0].id}
									isAuthor={!shared}
									readOnly={isReadOnly}
									model={currentModel}
									on:retry
									on:vote
									on:continue
								/>
							</div>
						{:else if pending}
							<ChatMessage
								loading={true}
								messages={[
									{
										id: "0-0-0-0-0",
										content: "",
										from: "assistant",
										children: [],
									},
								]}
								id={"0-0-0-0-0"}
								isAuthor={!shared}
								readOnly={isReadOnly}
								model={currentModel}
							/>
						{:else if !assistant}
							<ChatIntroduction
								{models}
								{currentModel}
								on:message={(ev) => {
									if ($page.data.loginRequired) {
										ev.preventDefault();
										loginModalOpen = true;
									} else {
										dispatch("message", ev.detail);
									}
								}}
							/>
						{:else}
							<AssistantIntroduction
								{assistant}
								on:message={(ev) => {
									if ($page.data.loginRequired) {
										ev.preventDefault();
										loginModalOpen = true;
									} else {
										dispatch("message", ev.detail);
									}
								}}
							/>
						{/if}
					</div>
				</div>
				<div
					class="dark:via-gray-80 pointer-events-none absolute inset-x-0 bottom-0 z-0 mx-auto flex w-full max-w-3xl flex-col items-center justify-center bg-gradient-to-t from-white via-white/80 to-white/0 px-3.5 py-4 dark:border-gray-800 dark:from-gray-900 dark:to-gray-900/0 max-md:border-t max-md:bg-white max-md:dark:bg-gray-900 sm:px-5 md:py-8 xl:max-w-4xl [&>*]:pointer-events-auto"
				>
					{#if sources.length}
						<div class="flex flex-row flex-wrap justify-center gap-2.5 max-md:pb-3">
							{#each sources as source, index}
								{#await source then src}
									<div class="relative h-16 w-16 overflow-hidden rounded-lg shadow-lg">
										<img
											src={`data:image/*;base64,${src}`}
											alt="input content"
											class="h-full w-full rounded-lg bg-gray-400 object-cover dark:bg-gray-900"
										/>
										<!-- add a button on top that deletes this image from sources -->
										<button
											class="absolute left-1 top-1"
											on:click={() => {
												files = files.filter((_, i) => i !== index);
											}}
										>
											<CarbonClose class="text-md font-black text-gray-300  hover:text-gray-100" />
										</button>
									</div>
								{/await}
							{/each}
						</div>
					{/if}

					<div class="w-full">
						<div class="flex w-full pb-3">
							{#if $page.data.settings?.searchEnabled && !assistant}
								<WebSearchToggle />
							{/if}
							{#if loading}
								<StopGeneratingBtn classNames="ml-auto" on:click={() => dispatch("stop")} />
							{:else if lastIsError}
								<RetryBtn
									classNames="ml-auto"
									on:click={() => {
										if (lastMessage && lastMessage.ancestors) {
											dispatch("retry", {
												id: lastMessage.id,
											});
										}
									}}
								/>
							{:else}
								<div class="ml-auto gap-2">
									{#if currentModel.multimodal}
										<UploadBtn bind:files classNames="ml-auto" />
									{/if}
									{#if messages && lastMessage && lastMessage.interrupted && !isReadOnly}
										<ContinueBtn
											on:click={() => {
												if (lastMessage && lastMessage.ancestors) {
													dispatch("continue", {
														id: lastMessage?.id,
													});
												}
											}}
										/>
									{/if}
								</div>
							{/if}
						</div>
						<form
							on:dragover={onDragOver}
							on:dragenter={onDragEnter}
							on:dragleave={onDragLeave}
							tabindex="-1"
							aria-label="file dropzone"
							on:submit|preventDefault={handleSubmit}
							class="relative flex w-full max-w-4xl flex-1 items-center rounded-xl border bg-gray-100 focus-within:border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:focus-within:border-gray-500
					{isReadOnly ? 'opacity-30' : ''}"
						>
							{#if onDrag && currentModel.multimodal}
								<FileDropzone bind:files bind:onDrag />
							{:else}
								<div class="flex w-full flex-1 border-none bg-transparent">
									{#if lastIsError}
										<ChatInput
											value="Sorry, something went wrong. Please try again."
											disabled={true}
										/>
									{:else if hasListened}
										<ChatInput
											placeholder="Ask anything"
											bind:value={outputText}
											on:submit={handleSubmit}
											on:beforeinput={(ev) => {
												if ($page.data.loginRequired) {
													ev.preventDefault();
													loginModalOpen = true;
												}
											}}
											maxRows={6}
											disabled={isReadOnly || lastIsError}
										/>
									{:else}
										<ChatInput
											placeholder="Ask anything"
											bind:value={message}
											on:submit={handleSubmit}
											on:beforeinput={(ev) => {
												if ($page.data.loginRequired) {
													ev.preventDefault();
													loginModalOpen = true;
												}
											}}
											maxRows={6}
											disabled={isReadOnly || lastIsError}
										/>
									{/if}

									{#if loading}
										<button
											class="btn mx-1 my-1 inline-block h-[2.4rem] self-end rounded-lg bg-transparent p-1 px-[0.7rem] text-gray-400 enabled:hover:text-gray-700 disabled:opacity-60 enabled:dark:hover:text-gray-100 dark:disabled:opacity-40 md:hidden"
											on:click={() => dispatch("stop")}
										>
											<CarbonStopFilledAlt />
										</button>
										<div
											class="mx-1 my-1 hidden h-[2.4rem] items-center p-1 px-[0.7rem] text-gray-400 enabled:hover:text-gray-700 disabled:opacity-60 enabled:dark:hover:text-gray-100 dark:disabled:opacity-40 md:flex"
										>
											<EosIconsLoading />
										</div>
									{:else}
										<div>
											<!-- <button on:click={runSpeechRecog} disabled={isListening}>Start Listening</button> -->
											<svg
												on:click={runSpeechRecog}
												fill="#000000"
												style="margin-top: 14px; cursor: pointer"
												height="20px"
												width="20px"
												version="1.1"
												xmlns="http://www.w3.org/2000/svg"
												viewBox="0 0 512 512"
												xmlns:xlink="http://www.w3.org/1999/xlink"
												enable-background="new 0 0 512 512"
											>
												<g>
													<g>
														<path
															d="m439.5,236c0-11.3-9.1-20.4-20.4-20.4s-20.4,9.1-20.4,20.4c0,70-64,126.9-142.7,126.9-78.7,0-142.7-56.9-142.7-126.9 0-11.3-9.1-20.4-20.4-20.4s-20.4,9.1-20.4,20.4c0,86.2 71.5,157.4 163.1,166.7v57.5h-23.6c-11.3,0-20.4,9.1-20.4,20.4 0,11.3 9.1,20.4 20.4,20.4h88c11.3,0 20.4-9.1 20.4-20.4 0-11.3-9.1-20.4-20.4-20.4h-23.6v-57.5c91.6-9.3 163.1-80.5 163.1-166.7z"
														/>
														<path
															d="m256,323.5c51,0 92.3-41.3 92.3-92.3v-127.9c0-51-41.3-92.3-92.3-92.3s-92.3,41.3-92.3,92.3v127.9c0,51 41.3,92.3 92.3,92.3zm-52.3-220.2c0-28.8 23.5-52.3 52.3-52.3s52.3,23.5 52.3,52.3v127.9c0,28.8-23.5,52.3-52.3,52.3s-52.3-23.5-52.3-52.3v-127.9z"
														/>
													</g>
												</g>
											</svg>
										</div>
										<button
											class="btn mx-1 my-1 h-[2.4rem] self-end rounded-lg bg-transparent p-1 px-[0.7rem] text-gray-400 enabled:hover:text-gray-700 disabled:opacity-60 enabled:dark:hover:text-gray-100 dark:disabled:opacity-40"
											disabled={!message || isReadOnly}
											type="submit"
										>
											<CarbonSendAltFilled />
										</button>
									{/if}
								</div>
							{/if}
						</form>
						<div
							class="mt-2 flex justify-between self-stretch px-1 text-xs text-gray-400/90 max-md:mb-2 max-sm:gap-2"
						>
							<p>
								Model:
								{#if !assistant}
									<a href="{base}/settings/{currentModel.id}" class="hover:underline"
										>{currentModel.displayName}</a
									>{:else}
									{@const model = models.find((m) => m.id === assistant?.modelId)}
									<a
										href="{base}/settings/assistants/{assistant._id}"
										class="inline-flex items-center border-b hover:text-gray-600 dark:border-gray-700 dark:hover:text-gray-300"
										>{model?.displayName}<CarbonCaretDown class="text-xxs" /></a
									>{/if} <span class="max-sm:hidden">·</span><br class="sm:hidden" /> Generated content
								may be inaccurate or false.
							</p>
							{#if messages.length}
								<button
									class="flex flex-none items-center hover:text-gray-400 max-sm:rounded-lg max-sm:bg-gray-50 max-sm:px-2.5 dark:max-sm:bg-gray-800"
									type="button"
									class:hover:underline={!isSharedRecently}
									on:click={onShare}
									disabled={isSharedRecently}
								>
									{#if isSharedRecently}
										<CarbonCheckmark class="text-[.6rem] sm:mr-1.5 sm:text-green-600" />
										<div class="text-green-600 max-sm:hidden">Link copied to clipboard</div>
									{:else}
										<CarbonExport class="sm:text-primary-500 text-[.6rem] sm:mr-1.5" />
										<div class="max-sm:hidden">Share this conversation</div>
									{/if}
								</button>
							{/if}
						</div>
					</div>
				</div>
			</div>

			<!-- Sidebar container -->
			<div class="h-full w-[300px] bg-gray-100 p-4">
				<!-- Existing sidebar content -->

				<!-- Knowledge Base Section -->
				<div class="knowledge-base mt-4">
					<h2 class="mb-2 text-lg font-semibold">Knowledge Base</h2>
					<textarea
						class="h-64 w-full rounded-md border bg-white p-2"
						placeholder="Type your notes or paste knowledge base content here..."
						bind:value={knowledgeBaseContent}
						on:input={saveKnowledgeBaseContent}
					></textarea>
				</div>

				<!-- Input History Section -->
				<div class="mt-4">
					<h2 class="mb-2 text-lg font-semibold">Input History</h2>
					{#each messages as msg}
						{#if msg.from == "user"}
							<div
								class="mb-2 rounded bg-zinc-300 pl-2 hover:bg-zinc-200 dark:bg-gray-900"
								on:click={() =>
									document.getElementById(msg.id).scrollIntoView({ behavior: "smooth" })}
							>
								{msg.content}
							</div>
						{/if}
					{/each}
				</div>
			</div>
		</div>
		<ScrollToBottomBtn
			class="bottom-36 right-4 max-md:hidden lg:right-10"
			scrollNode={chatContainer}
		/>
	</div>
</div>
