// The module 'vscode' contains the VS Code extensibility API
// Import the module and reference it with the alias vscode in your code below
import * as vscode from "vscode";

// This method is called when your extension is activated
// Your extension is activated the very first time the command is executed
export function activate(context: vscode.ExtensionContext) {
  {// Use the console to output diagnostic information (console.log) and errors (console.error)
  // This line of code will only be executed once when your extension is activated
  console.log('Congratulations, your extension "ironclad" is now active!');

  // The command has been defined in the package.json file
  // Now provide the implementation of the command with registerCommand
  // The commandId parameter must match the command field in package.json
  const disposable = vscode.commands.registerCommand(
    "ironclad.helloWorld",
    () => {
      // The code you place here will be executed every time your command is executed
      // Display a message box to the user
      vscode.window.showInformationMessage("Hello World from IRONCLAD!");
    }
  );}


  //make only allow user to select from the three options ollama openrouter vscode
  // avalable in menu and also through the command pallet
  const provider = vscode.commands.registerCommand(
    "ironclad.selectProvider",
    async() => {
		// would be nice to have the list come from the backend
		const providers = ['ollama', 'openrouter', 'vscode']; 
		const selected = await vscode.window.showQuickPick(providers);

		if (selected) {
			// a function with logic for selcting provider will be used here 
		} else {

		};

    }
  );

	// specify a AI model to be used from the provider
  // make the only options the list of avalable models
  // avalable in menu and also through the command pallet
  const model = vscode.commands.registerCommand(
    "ironclad.selectModel",
    async() => {
		// if there are no models error out and request a provider to be chosen      
		const models = [""];// this will be a list gotten from the back end 
		const selected = await vscode.window.showQuickPick(models);

		if (selected) {
			// a function with logic for selecting models will be used here 
		} else {

		};
    }
  );


  //specify an endpoint for ollama ai model
  // avalable in menu and also through the command pallet
  const endpoint = vscode.commands.registerCommand(
    "ironclad.OllamaEndpoint",
    async() => {
      
		const endpoint = await vscode.window.showInputBox({ 
			placeHolder: 'Enter ollama endpoint',
			prompt:'Enter ollama endpoint',
		});

		if (endpoint === undefined) {
            // this is if the user cancelled
        } else {
            // set the ollama endpoint with this
        }
    }
  );

  


  // set The maximum tokens that a rquest is allowed to consume.
  // avalable in menu and also through the command pallet
  const tokens = vscode.commands.registerCommand(
    "ironclad.setMaxTokens",
    async() => {
      
		const endpoint = await vscode.window.showInputBox({ 
			placeHolder: 'set the maximum tokens that a request is allowed to consume',
			prompt:'set the maximum tokens that a request is allowed to consume',
		});

		if (endpoint === undefined) {
            // this is if the user cancelled
        } else {
            const endpointint = parseInt(endpoint);
        }
    }
  );

  ("make the mode selection happen in the actual ui ");
  ("-M, --mode <MODE>             Specify operation mode. Defaults to diff.");
  ("full                Do a full code scan.");
  ("diff                Do a scan over the git diffs.");// will be added later
  // when diff scan is selected make sure to ask for what commit to diff against
  ("file                Do a check on a file.");
  // when file scan is selected make sure to either ask for what file to scan(if done from side bar) 
  // if key bind is used that file the file the keybind was pressed on will be used
  // if a file is right clicked this should work as well 
  
  // this will scan a file depending on if the user is using the editor or uses a command 
  const scanfile = vscode.commands.registerCommand(
	"ironclad.",
	async() => {

		const fileLocation = await vscode.window.showInputBox({ 
			placeHolder: 'what file ',
			prompt:'set the maximum tokens that a request is allowed to consume',
		});

		if (endpoint === undefined) {
            // this is if the user cancelled
        } else {
            const endpointint = parseInt(endpoint);
        }
	}
  );
  

  // does a scan of a string (highlighted code) 
  const spotScan = vscode.commands.registerCommand(
    "ironclad.spotscan",
    () => {
      
    }
  );

  context.subscriptions.push( provider);
}

// This method is called when your extension is deactivated
export function deactivate() {}
