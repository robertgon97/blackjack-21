// Configuración de ESLint para las Cloud Functions (TypeScript).
// ESLint 8 usa el formato legacy `.eslintrc.*`. Solo se analiza `src/`;
// el directorio compilado `lib/` y `node_modules/` quedan excluidos.
module.exports = {
  root: true,
  env: {
    es2020: true,
    node: true,
  },
  parser: '@typescript-eslint/parser',
  parserOptions: {
    ecmaVersion: 2020,
    sourceType: 'module',
  },
  plugins: ['@typescript-eslint'],
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
  ],
  ignorePatterns: [
    'lib/',
    'node_modules/',
    '.eslintrc.js',
  ],
  rules: {},
};
