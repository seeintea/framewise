export default {
  '*.{js,jsx,ts,tsx,mjs,cjs}': [
    'prettier --write',
    'eslint --fix --max-warnings=0',
  ],
  '*.{json,jsonc,md,mdx,yaml,yml}': 'prettier --write',
};
