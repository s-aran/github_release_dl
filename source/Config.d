module Config;

import std.stdio;
import std.format;
import std.json;
import std.file;

import Logger;

class Config
{
  public static string config_filepath = "package.json";
  public static EzLogger.Level log_level = EzLogger.Level.Critical;
  public static string download_dest = "tmp/";
  public static string github_oauth_token = "";

  public static download_only = false;
  public static install_only = false;
}

class ConfigFile
{
  private string path;

  public this(string filepath)
  {
    this.path = filepath;
  }

  private EzLogger get_logger()
  {
    return EzLogger.get_logger("config");
  }

  public void load()
  {
    if (!exists(this.path) || !isFile(this.path))
    {
      return;
    }

    auto logger = this.get_logger();
    logger.info(format("found: %s", this.path));

    auto file = File(this.path, "rb");
    auto content = file.rawRead(new char[file.size]);
    file.close();

    auto json = parseJSON(content).object;
    this.build(json);
  }

  private void build(JSONValue[string] document)
  {

    if ("auth" in document)
    {
      auto logger = this.get_logger();

      auto doc_auth = document["auth"].object;
      auto auth_token = "";


      if ("token" in doc_auth)
      {
        auth_token = doc_auth["token"].str;
        logger.info(format("GitHub oauth token: %s", auth_token));
      }

      Config.github_oauth_token = auth_token;
    }
  }
}