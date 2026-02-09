
const { PromptPart } = require("../types");

/**
 * Placeholder for calling a Foundry agent.
 *
 * @param {object} options - The options for the AI call.
 * @param {string} options.model - The model to use.
 * @param {PromptPart[]} options.messages - The messages to send to the model.
 * @param {AITool[]} [options.tools] - The tools available to the model.
 * @returns {Promise<PromptPart>} The response from the AI model.
 */
async function call({ model, messages, tools }) {
  console.log(`--- Calling Foundry Agent: ${model} ---`);

  // In a real implementation, you would make an API call to the
  // Foundry service here. This is a placeholder response.
  const lastUserMessage = messages[messages.length - 1];
  const responseContent = `This is a placeholder response from Foundry agent for the prompt: "${lastUserMessage.content.substring(0, 50)}..."`;

  // Return a response in the expected format (PromptPart.assistant)
  return PromptPart.assistant(responseContent);
}

module.exports = {
  call,
};
