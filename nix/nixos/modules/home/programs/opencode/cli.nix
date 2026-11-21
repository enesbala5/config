{
  config,
  lib,
  data,
  ...
}:

{
  config = lib.mkIf config.modules.home.opencode.enable {
    # Link to the checkout, not a store copy, so preference edits need no rebuild.
    xdg.configFile."opencode/cli.json".source =
      config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/tools/opencode/cli.json";
  };
}
