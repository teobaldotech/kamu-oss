import airbnb from "eslint-config-airbnb-base-x/flat";
import globals from "globals";

/**

* ============================================================
* ESLint PRO — Flat Config
* ============================================================
*
* Funcionalidades:
* * Configurações recomendadas do Airbnb.
* * Suporte a JavaScript moderno.
* * Separação entre ESM e CommonJS.
* * Ambientes Browser e Node.js.
* * Indentação com tabulações.
* * Detecção de variáveis não utilizadas.
* * Identificação de diretivas eslint-disable desnecessárias.
*
* Requisitos:
* * ESLint compatível com Flat Config.
* * eslint-config-airbnb-base-x com os exports utilizados.
* * globals.
    */

const sharedRules = {
// Padroniza a indentação com tabulações.
indent: ["error", "tab"],
"no-tabs": "off",

```
// Detecta variáveis e parâmetros não utilizados.
"no-unused-vars": [
	"error",
	{
		vars: "all",
		args: "all",
		argsIgnorePattern: "^_",
		caughtErrors: "all",
		caughtErrorsIgnorePattern: "^_",
		varsIgnorePattern: "^_",
	},
],
```

};

// Configurações compartilhadas dos ambientes.
const browserGlobals = {
...globals.browser,
document: "readonly",
};

const nodeGlobals = {
...globals.node,
};

const commonLanguageOptions = {
ecmaVersion: 2021,
};

// Configuração para arquivos JavaScript com módulos ES.
const esmConfig = {
files: ["**/*.js", "**/*.mjs"],

```
languageOptions: {
	...commonLanguageOptions,
	sourceType: "module",

	globals: {
		...browserGlobals,
		...nodeGlobals,
	},
},

rules: sharedRules,
```

};

// Configuração para arquivos CommonJS.
const commonJsConfig = {
files: ["**/*.cjs"],

```
languageOptions: {
	...commonLanguageOptions,
	sourceType: "commonjs",

	globals: nodeGlobals,
},

rules: sharedRules,
```

};

// Configuração para verificar diretivas de desativação de regras.
const linterOptionsConfig = {
linterOptions: {
reportUnusedDisableDirectives: "error",
},
};

// Exporta a configuração completa.
export default [
// Regras recomendadas do Airbnb.
...airbnb.recommended,
...airbnb.recommendedNode,

```
// Regras específicas do projeto.
esmConfig,
commonJsConfig,
linterOptionsConfig,
```

];
