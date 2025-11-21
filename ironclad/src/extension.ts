// The module 'vscode' contains the VS Code extensibility API
// Import the module and reference it with the alias vscode in your code below
import * as vscode from "vscode";


// This method is called when your extension is activated
// Your extension is activated the very first time the command is executed
export function activate(context: vscode.ExtensionContext) {


  const terminal = vscode.window.createTerminal("ironcladTerminal");


  (" ------------------- config --------------- ");
 
  //make only allow user to select from the three options ollama openrouter vscode
  // avalable in menu and also through the command pallet
  const provider = vscode.commands.registerCommand(
    "ironclad.selectProvider",
    async () => {
      const providers = ["ollama", "openrouter", "vscode"];
            const selected = await vscode.window.showQuickPick(providers, {
                placeHolder: "Select AI provider for vulnerability analysis",
                title: "AI Provider Selection"
            });

            if (selected) {
                await updateConfig('ironclad.provider', selected);
                vscode.window.showInformationMessage(`AI Provider set to: ${selected}`);
            } else {
                const currentProvider = getConfig('ironclad.provider');
                if (currentProvider) {
                    vscode.window.showInformationMessage(`Current provider: ${currentProvider}`);
                } else {
                    vscode.window.showWarningMessage('No provider selected. Please select a provider.');
                }
            }
        }
  );

  // specify a AI model to be used from the provider
  // make the only options the list of avalable models
  // avalable in menu and also through the command pallet
  const model = vscode.commands.registerCommand(
    "ironclad.selectModel",
    async () => {
      // if there are no models error out and request a provider to be chosen
      const models = [""]; // this will be a list gotten from the back end
      const selected = await vscode.window.showQuickPick(models);

      if (selected) {
        // a function with logic for selecting models will be used here
      } else {
		// logic for if there a model in the config vs not
      }
    }
  );

  //specify an endpoint for ollama ai model
  // avalable in menu and also through the command pallet
  const endpoint = vscode.commands.registerCommand(
    "ironclad.OllamaEndpoint",
    async () => {
      const endpoint = await vscode.window.showInputBox({
        placeHolder: "Enter ollama endpoint",
        prompt: "Enter ollama endpoint",
      });

      if (endpoint === undefined) {
        // this is if the user cancelled
		// logic for if there a endpoint in the config for ollama vs not

      } else {
        // set the ollama endpoint with this
      }
    }
  );

  // set The maximum tokens that a rquest is allowed to consume.
  // avalable in menu and also through the command pallet
  const tokens = vscode.commands.registerCommand(
    "ironclad.setMaxTokens",
    async () => {
      const endpoint = await vscode.window.showInputBox({
        placeHolder:
          "set the maximum tokens that a request is allowed to consume",
        prompt: "set the maximum tokens that a request is allowed to consume",
      });

      if (endpoint === undefined) {
        // this is if the user cancelled
		// logic for if there a token amount in the config for openrouter vs not
      } else {
        const endpointint = parseInt(endpoint);
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
            case 'ollama':
                return ['llama2', 'codellama', 'mistral'];
            case 'openrouter':
                return ['gpt-4', 'claude-2', 'llama-2-70b'];
            case 'vscode':
                return ['vscode-native'];
            default:
                return [];
        }
    }

  function getConfig<T>(key: string): T | undefined {
        return vscode.workspace.getConfiguration('ironclad').get<T>(key);
    }

    async function updateConfig(key: string, value: any): Promise<void> {
        await vscode.workspace.getConfiguration('ironclad').update(key, value, true);
    }

  context.subscriptions.push(provider, model, spotScan, scanfile, fullscan, tokens,endpoint , );
}

// This method is called when your extension is deactivated
export function deactivate() {}
