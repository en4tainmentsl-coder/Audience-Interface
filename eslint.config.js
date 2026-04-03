import globals from "globals";

export default [
  {
    ignores: ["dist/**", "node_modules/**"],
  },
  {
    files: ["**/*.{js,jsx}"],
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module",
      globals: {
        ...globals.browser,
        ...globals.node,
      },
      parserOptions: {
        ecmaFeatures: {
          jsx: true,
        },
      },
    },
    plugins: {
      react: (await import("eslint-plugin-react")).default,
      "react-hooks": (await import("eslint-plugin-react-hooks")).default,
      "react-refresh": (await import("eslint-plugin-react-refresh")).default,
    },
    rules: {
      "no-undef": "error",
      "no-unused-vars": "warn",
      "react/jsx-uses-react": "error",
      "react/jsx-uses-vars": "error",
    },
  },
];
