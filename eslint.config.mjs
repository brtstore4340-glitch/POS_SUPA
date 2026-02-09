import js from '@eslint/js';
import globals from 'globals';
import reactHooks from 'eslint-plugin-react-hooks';
import reactRefresh from 'eslint-plugin-react-refresh';

export default [
  {
    ignores: [
      "**/dist/**",
      "**/build/**",
      "**/coverage/**",
      "**/node_modules/**",
      "**/.backup-*/**",
      "**/.backup-eslint-*/**",
      "**/.backup-eslint-fix*/**",
      "**/*.min.js",
      "**/*.min.*",
      ".diag/**",
      ".firebase/**",
      ".boots-logs/**",
      "_boot/**",
      "ai-backups/**",
      "tools/logs/**",
      "functions/**",
      "index_fixed.js",
      "service-account.json",
      "src/toggle/**",
    ],
  },
  {
    // Node/CommonJS files: allow require/module/exports/process
    files: [
      "**/vite.config.js",
      "**/tailwind.config.js",
      "**/*.config.js",
      "pos-gem/functions/**/*.js",
      "pos-gem/functions/src/**/*.js",
      "shared/**/*.js"
    ],
    languageOptions: {
      globals: {
        require: "readonly",
        module: "readonly",
        exports: "readonly",
        process: "readonly"
      }
    }
  },
  {
    files: ['**/*.{js,jsx}'],
    languageOptions: {
      ecmaVersion: 2020,
      globals: globals.browser,
      parserOptions: {
        ecmaVersion: 'latest',
        ecmaFeatures: { jsx: true },
        sourceType: 'module',
      },
    },
    plugins: {
      'react-hooks': reactHooks,
      'react-refresh': reactRefresh,
    },
    rules: {
      ...js.configs.recommended.rules,
      ...reactHooks.configs.recommended.rules,

      // ✅ เป้าหมาย: เอา warnings ออกทั้งหมด (ตามที่คุณขอ)
      'no-unused-vars': 'off',
      'react-hooks/exhaustive-deps': 'off',

      'react-refresh/only-export-components': ['warn', { allowConstantExport: true }],
    },
  },
];
