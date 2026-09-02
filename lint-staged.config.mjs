export default {
  '*.{js,jsx,ts,tsx,mjs,cjs}': [
    'prettier --write',
    'eslint --fix --max-warnings=0 --no-warn-ignored',
  ],
  '*.{json,jsonc,md,mdx,yaml,yml}': 'prettier --write',
};
