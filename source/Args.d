module Args;

import std.stdio;
import std.getopt;
import std.format;
import core.stdc.stdlib: exit;

import Config: Config;
import Logger;
import VersionInfo;


class Arguments
{
  static void package_json_file_callback(string op, string v)
  {
    auto logger = EzLogger.get_logger("main");
    logger.trace(format("specified --package option. package.json ==> %s", v));
    Config.config_filepath = v;
  }

  static void loglevel_callback(string op)
  {
    switch (op)
    {
      case "trace":
        Config.log_level = EzLogger.Level.Trace;
        break;
      case "info":
        Config.log_level = EzLogger.Level.Info;
        break;
      case "warn":
      case "warning":
        Config.log_level = EzLogger.Level.Warn;
        break;
      case "error":
        Config.log_level = EzLogger.Level.Error;
        break;
      case "critical":
        Config.log_level = EzLogger.Level.Critical;
        break;
      case "fatal":
        Config.log_level = EzLogger.Level.Fatal;
        break;
      default:
        return;
    }
    EzLogger.set_all_level(Config.log_level);
  }

  static void version_callback()
  {
    writefln("github_release_dl %s", VersionInfo.VersionInfo.VersionString);
    exit(0);
  }

  public static void analyze(string[] args) {
    // |        only        |          do         |
    // | download | install | download  | install | 
    // |----------|---------|-----------|---------|
    // | x        | x       | o         | o       |
    // | x        | o       | x         | o       |
    // | o        | x       | o         | x       |
    // | o        | o       | o         | o       |

    auto getopt_result = getopt(args, 
        "download-only"   , "check for updates and download assets"     , &Config.download_only, 
        "install-only"    , "install the files that exists in tmp/"     , &Config.install_only, 
        "trace"           , "set log level to trace"                    , &loglevel_callback, 
        "info"            , "set log level to info"                     , &loglevel_callback, 
        "warn"            , "set log level to warn"                     , &loglevel_callback, 
        "warning"         , "set log level to warn"                     , &loglevel_callback, 
        "error"           , "set log level to error"                    , &loglevel_callback, 
        "critical"        , "set log level to critical"                 , &loglevel_callback, 
        "fatal"           , "set log level to fatal"                    , &loglevel_callback,
        "package|p"       , "load specified alternative package.json"   , &package_json_file_callback,
        "version"         , "show version"                              , &version_callback
      );
    if (getopt_result.helpWanted)
    {
      defaultGetoptPrinter("option help", getopt_result.options);
      exit(255);
    }
  }
}
