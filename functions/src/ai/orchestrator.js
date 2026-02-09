const {
  AIService,
  AITool,
  AIFunction,
  AIProvider,
  PromptPart,
  AIModel,
} = require("./types");
const { call: callFoundry } = require("./providers/foundry");

// --- Tool Definitions ---

const listProductsTool = new AITool({
  name: "list_products",
  description: "Get a list of available products",
  inputSchema: {
    type: "object",
    properties: {
      category: {
        type: "string",
        description: "Filter by category",
      },
    },
  },
});

const getProductDetailTool = new AITool({
  name: "get_product_detail",
  description: "Get the details of a specific product",
  inputSchema: {
    type: "object",
    properties: {
      sku: {
        type: "string",
        description: "The SKU of the product",
      },
    },
    required: ["sku"],
  },
});

// --- Function Implementations ---

const listProductsFunction = new AIFunction({
  tool: listProductsTool,
  async implementation(input) {
    // In a real app, this would call the product service
    console.log("TOOL: list_products called with:", input);
    return {
      success: true,
      data: [
        { sku: "SKU-001", name: "Cleansing Gel", price: 390 },
        { sku: "SKU-002", name: "Vitamin C Serum", price: 990 },
      ],
    };
  },
});

const getProductDetailFunction = new AIFunction({
  tool: getProductDetailTool,
  async implementation(input) {
    console.log("TOOL: get_product_detail called with:", input);
    // In a real app, this would call the product service
    if (input.sku === "SKU-001") {
      return {
        success: true,
        data: {
          sku: "SKU-001",
          name: "Cleansing Gel",
          price: 390,
          description: "A gentle cleansing gel for all skin types.",
        },
      };
    }
    return { success: false, error: "Product not found" };
  },
});

// --- AI Service Definition ---

class POSAIService extends AIService {
  constructor() {
    super({
      name: "pos_ai_service",
      description: "AI assistant for the Point of Sale system",
      tools: [listProductsTool, getProductDetailTool],
      functions: [listProductsFunction, getProductDetailFunction],
      providers: [
        new AIProvider({
          name: "foundry",
          implementation: callFoundry,
          supportedModels: [AIModel.FOUNDRY_AGENT_1],
          isDefault: true,
        }),
      ],
    });
  }

  // Override or add methods as needed
}

const posAIService = new POSAIService();

// --- Main Orchestration Logic ---

async function orchestrate(
  userPrompt,
  options = {
    providerName: null,
    modelName: null,
    maxToolRoundtrips: 5,
  },
) {
  let messages = [PromptPart.user(userPrompt)];
  let roundtrips = 0;

  while (roundtrips < options.maxToolRoundtrips) {
    const { provider, model } = posAIService.getProviderAndModel(
      options.providerName,
      options.modelName,
    );
    if (!provider || !model) {
      throw new Error("Could not find a suitable AI provider or model.");
    }

    console.log(`🧠 Calling ${provider.name} with model ${model}...`);

    const response = await provider.implementation({
      model,
      messages,
      tools: posAIService.tools,
    });

    // Add assistant''s response to messages
    messages.push(response);

    if (response.toolCalls && response.toolCalls.length > 0) {
      console.log(`🛠️ Tools called:`, response.toolCalls.map((t) => t.name));
      const toolResults = await posAIService.executeToolCalls(
        response.toolCalls,
      );
      // Add tool results to messages
      messages = messages.concat(toolResults);
    } else {
      // No tool calls, this is the final answer
      console.log("✅ Final response received.");
      return response;
    }

    roundtrips++;
  }

  throw new Error("Exceeded maximum tool roundtrips.");
}

module.exports = {
  orchestrate,
  posAIService,
};
