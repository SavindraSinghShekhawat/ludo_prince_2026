const eslint = require('@eslint/js');
const tseslint = require('typescript-eslint');
const globals = require('globals');

module.exports = tseslint.config(
  {
    ignores: ["lib/**/*", "generated/**/*", ".eslintrc.js", "eslint.config.js", "coverage/**/*", "**/*.d.ts"]
  },
  eslint.configs.recommended,
  ...tseslint.configs.recommended,
  {
    languageOptions: {
      globals: {
        ...globals.node,
        ...globals.es2015
      },
      parserOptions: {
        project: ["tsconfig.json", "tsconfig.dev.json"],
        tsconfigRootDir: __dirname,
      }
    },
    rules: {
      "quotes": ["error", "double"],
      "indent": ["error", 2],
      "require-jsdoc": "off",
      "valid-jsdoc": "off",
      "max-len": ["error", {"code": 140}]
    }
  }
);
