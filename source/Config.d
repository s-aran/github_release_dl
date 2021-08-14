module Config;

import Logger;

class Config
{
  public static string config_filepath = "package.json";
  public static EzLogger.Level log_level = EzLogger.Level.Critical;
  public static string download_dest = "tmp/";

  public static download_only = false;
  public static install_only = false;
}
