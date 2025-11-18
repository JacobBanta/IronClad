# VSCode extension
* UI
    * Something simple that hooks into the [activity bar](https://code.visualstudio.com/api/ux-guidelines/activity-bar)
        * We need an icon
    * A simple display in the [primary sidebar](https://code.visualstudio.com/api/ux-guidelines/sidebars#primary-sidebar)
        * this should be a light wrapper around the backend
    * An [editor action](https://code.visualstudio.com/api/ux-guidelines/editor-actions) would also be nice to have
* Integration
    * The [Language Model API](https://code.visualstudio.com/api/extension-guides/ai/language-model)
        * This might mean it will be better to split the two halves, but im not sure
# CLI
* This will just be a light wrapper around the backend
* It shouldn't be too complicated as long as the backend is well made
# Backend
* able to traverse a project, and split each function while preserving enough context to diagnose vulnerabilities
    * should work for every popular language
* use multiple different APIs
    * [Language Model API](https://code.visualstudio.com/api/extension-guides/ai/language-model)
    * OLLaMA
    * openrouter
* use multiple models for each API
* ability to set a token max and scale usage accordingly
* ability to summarize each output and aggregate them into the result file/`stdout`

