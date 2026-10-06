const path = require('path');
const { getDefaultConfig } = require('@react-native/metro-config');
const { getConfig } = require('react-native-builder-bob/metro-config');
const pkg = require('../package.json');

const root = path.resolve(__dirname, '..');

/**
 * Metro configuration
 * https://facebook.github.io/metro/docs/configuration
 *
 * @type {import('metro-config').MetroConfig}
 */
const config = getConfig(getDefaultConfig(__dirname), {
  root,
  pkg,
  project: __dirname,
});

// The example does not install the library into its own node_modules, so map
// its package name directly to the monorepo root for Metro resolution.
config.resolver.extraNodeModules = {
  ...config.resolver.extraNodeModules,
  [pkg.name]: root,
};

module.exports = config;
