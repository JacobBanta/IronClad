// The module 'vscode' contains the VS Code extensibility API
// Import the module and reference it with the alias vscode in your code below
import { type } from "os";
import * as vscode from "vscode";

// This method is called when your extension is activated
// Your extension is activated the very first time the command is executed
export function activate(context: vscode.ExtensionContext) {
  const terminal = vscode.window.createTerminal("ironcladTerminal");

  (" ------------------- config --------------- ");

  // ^ avalable in menu and also through the command pallet
  const provider = vscode.commands.registerCommand(
    "ironclad.selectProvider",
    async () => {
      const providers = ["ollama", "openrouter", "vscode"];
      const selected = await vscode.window.showQuickPick(providers, {
        placeHolder: "Select AI provider for vulnerability analysis",
        title: "AI Provider Selection",
      });

      if (selected) {
        await updateConfig("provider", selected);
        vscode.window.showInformationMessage(`AI Provider set to: ${selected}`);
      } else {
        const currentProvider = getConfig("provider");
        if (currentProvider) {
          vscode.window.showInformationMessage(
            `Current provider: ${currentProvider}`
          );
        } else {
          vscode.window.showWarningMessage(
            "No provider selected. Please select a provider."
          );
        }
      }
    }
  );

  //  ^ avalable in menu and also through the command pallet
  const model = vscode.commands.registerCommand(
    "ironclad.selectModel",
    async () => {
      const currentProvider = getConfig<string>("provider");
      if (!currentProvider) {
        vscode.window.showWarningMessage(
          'Please select a provider first using "Select AI Provider"'
        );
        vscode.commands.executeCommand("ironclad.selectProvider");
        vscode.commands.executeCommand("ironclad.selectModel");
        return;
      }

      // TODO Fetch models from backend based on provider
      const models = await fetchModels(currentProvider);

      if (models.length === 0) {
        vscode.window.showWarningMessage(
          `No models available for ${currentProvider}. Please check your configuration.`
        );
        return;
      }

      const selected = await vscode.window.showQuickPick(models, {
        placeHolder: `Select model for ${currentProvider}`,
        title: "AI Model Selection",
      });

      if (selected) {
        await updateConfig("model", selected);
        vscode.window.showInformationMessage(`AI Model set to: ${selected}`);
      } else {
        const currentModel = getConfig("model");
        if (currentModel) {
          vscode.window.showInformationMessage(
            `Current model: ${currentModel}`
          );
        }
      }
    }
  );

  // ^ specify an endpoint for ollama ai model
  // ^ avalable in menu and also through the command pallet
  const endpoint = vscode.commands.registerCommand(
    "ironclad.OllamaEndpoint",
    async () => {
      const currentEndpoint =
        getConfig<string>("ollamaEndpoint") || "http://localhost:11434";

      const endpoint = await vscode.window.showInputBox({
        value: currentEndpoint,
        placeHolder: "Enter Ollama endpoint (e.g., http://localhost:11434)",
        prompt: "Ollama API Endpoint",
        validateInput: (value) => {
          if (!value.startsWith("http://") && !value.startsWith("https://")) {
            return "Endpoint must start with http:// or https://";
          }
          return null;
        },
      });

      if (endpoint === undefined) {
        // & User cancelled - show current endpoint
        vscode.window.showInformationMessage(
          `Current Ollama endpoint: ${currentEndpoint}`
        );
      } else {
        await updateConfig("ollamaEndpoint", endpoint);
        vscode.window.showInformationMessage(
          `Ollama endpoint set to: ${endpoint}`
        );
      }
    }
  );

  // ^ set The maximum tokens that a request is allowed to consume.
  // ^ avalable in menu and also through the command pallet
  const tokens = vscode.commands.registerCommand(
    "ironclad.setMaxTokens",
    async () => {
      const currentTokens = getConfig("maxTokens") || 1000;

      const tokens = await vscode.window.showInputBox({
        value: currentTokens.toString(),
        placeHolder: "Set maximum tokens per request",
        prompt: "Maximum Tokens",
        validateInput: (value) => {
          const num = parseInt(value);
          if (isNaN(num) || num <= 0) {
            return "Please enter a positive number";
          }
          if (num > 100000) {
            return "Maximum tokens cannot exceed 100,000";
          }
          return null;
        },
      });

      if (tokens === undefined) {
        vscode.window.showInformationMessage(
          `Current max tokens: ${currentTokens}`
        );
      } else {
        const tokensInt = parseInt(tokens);
        await updateConfig("maxTokens", tokensInt);
        vscode.window.showInformationMessage(`Max tokens set to: ${tokensInt}`);
      }
    }
  );

  // ^ set api token with vscode secret api
  const setapikey = vscode.commands.registerCommand(
    "ironclad.setapikey",
    async () => {
      const apikey: string | undefined = await vscode.window.showInputBox({
        placeHolder: "input api key or type 'remove' to delete api key ",
        prompt: "input api key",
      });

      if (apikey === "remove") {
        await context.secrets.delete("myExtensionApiKey");
        vscode.window.showInformationMessage("api key removed successfully");
        return;
      }
      if (apikey === undefined) {
        // ^ this is if the user cancelled
        if (
          getConfig("provider") === "openrouter" &&
          (await context.secrets.get("myExtensionApiKey")) === undefined
        ) {
          vscode.window.showErrorMessage("openrouter requires a api key key ");
        }
      } else {
        await context.secrets.store("myExtensionApiKey", apikey);
        vscode.window.showInformationMessage("api key stored successfully");
      }
    }
  );

  (" ------------------- scanning functionality --------------- ");

  ("full                Do a full code scan.");
  const fullscan = vscode.commands.registerCommand("ironclad.fullscan", () => {
    // will scan the whole project including sub folders and such
  });

  ("diff                Do a scan over the git diffs."); // will be added later
  // when diff scan is selected make sure to ask for what commit to diff against

  ("file                Do a check on a file.");
  // when file scan is selected make sure to either ask for what file to scan(if done from side bar)
  // if key bind is used that file the file the keybind was pressed on will be used
  // if a file is right clicked this should work as well
  // this will scan a file depending on if the user is using the editor or uses a command
  const scanfile = vscode.commands.registerCommand(
    "ironclad.scanfile",
    async () => {
      const fileLocation = await vscode.window.showInputBox({
        placeHolder: "what is the location of the folder you wish to scan",
        prompt: "Write the location of the file you wish to scan",
      });

      if (fileLocation === undefined) {
        // this is if the user cancelled
      } else {
        // use terminal do a file check
      }
    }
  );
  (" -- spot scan -- ");
  // does a scan of a string (highlighted code)
  const spotScan = vscode.commands.registerCommand("ironclad.spotscan", () => {
    const editor = vscode.window.activeTextEditor;

    if (!editor) {
      vscode.window.showWarningMessage("No active editor found");
      return;
    }
    // this var will be fed into the termial
    const selectedText = editor.document.getText(editor.selection);
  });

  // ------ ** helper function **

  async function fetchModels(provider: string): Promise<string[]> {
    // TODO Implement actual model fetching from backend
    switch (provider) {
      case "ollama":
        return ["llama2", "codellama", "mistral"];
      case "openrouter":
        return ["gpt-4", "claude-2", "llama-2-70b"];
      case "vscode":
        return ["vscode-native"];
      default:
        return [];
    }
  }

  function getConfig<Type>(key: string): Type | undefined {
    return vscode.workspace.getConfiguration("ironclad").get<Type>(key);
  }

  async function updateConfig(key: string, value: any): Promise<void> {
    await vscode.workspace
      .getConfiguration("ironclad")
      .update(key, value, true);
  }

  context.subscriptions.push(
    provider,
    model,
    spotScan,
    scanfile,
    fullscan,
    tokens,
    endpoint,
    setapikey
  );
}

// This method is called when your extension is deactivated
export function deactivate() {}
