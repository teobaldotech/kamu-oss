
import airbnb from "eslint-config-airbnb-base-x/flat";
import globals from "globals";

/**
 * ESLint PRO — Flat Config
 *
 * Princípios aplicados:
 * - Configuração organizada e previsível.
 * - Separação entre ESM e CommonJS.
 * - Ambientes específicos por tipo de arquivo.
 * - Regras compartilhadas centralizadas.
 * - Identificação de variáveis não utilizadas.
 * - Detecção de diretivas eslint-disable desnecessárias.
 */

// ------------------------------------------------------------
// 1. Regras compartilhadas
// ------------------------------------------------------------

const sharedRules = {
	indent: ["error", "tab"],
	"no-tabs": "off",

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
};

// ------------------------------------------------------------
// 2. Opções de linguagem
// ------------------------------------------------------------

const commonLanguageOptions = {
	ecmaVersion: 2021,
};

// ------------------------------------------------------------
// 3. Configuração ESM — arquivos .js e .mjs
// ------------------------------------------------------------

const esmConfig = {
	files: ["**/*.js", "**/*.mjs"],

	languageOptions: {
		...commonLanguageOptions,
		sourceType: "module",

		globals: {
			...globals.browser,
			...globals.node,
		},
	},

	rules: sharedRules,
};

// ------------------------------------------------------------
// 4. Configuração CommonJS — arquivos .cjs
// ------------------------------------------------------------

const commonJsConfig = {
	files: ["**/*.cjs"],

	languageOptions: {
		...commonLanguageOptions,
		sourceType: "commonjs",

		globals: {
			...globals.node,
		},
	},

	rules: sharedRules,
};

// ------------------------------------------------------------
// 5. Opções do próprio ESLint
// ------------------------------------------------------------

const linterOptionsConfig = {
	linterOptions: {
		reportUnusedDisableDirectives: "error",
	},
};

// ------------------------------------------------------------
// 6. Exportação da configuração
// ------------------------------------------------------------

export default [
	...airbnb.recommended,
	...airbnb.recommendedNode,

	esmConfig,
	commonJsConfig,
	linterOptionsConfig,
];