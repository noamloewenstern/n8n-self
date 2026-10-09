import { Config, Env } from '../decorators';

const DEFAULT_SERVICE_BASE_URL = 'https://ai-assistant.n8n.io';

@Config
export class AiAssistantConfig {
	/** Base URL of the AI assistant service */
	@Env('N8N_AI_ASSISTANT_BASE_URL')
	// baseUrl: string = '';
	baseUrl: string = DEFAULT_SERVICE_BASE_URL; // CUSTOM PATCH
}
