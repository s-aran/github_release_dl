import std.stdio;
import std.string : fromStringz;
import std.json;
import std.conv;
import std.datetime.date : DateTime;
import std.array : join, replace;
import std.regex;
import std.net.curl;
import std.file;
import std.path;
import std.zip;
import std.array;
import std.getopt;
import std.format;
import core.stdc.stdlib: exit;

import VersionInfo;
import GitHub;
import PackageConfigure;
import FileUtils;
import Logger;


class Config
{
  static string config_filepath = "package.json";
  static EzLogger.Level log_level = EzLogger.Level.Critical;
}

void main(string[] args)
{
  auto logger = EzLogger.get_logger("main");
  EzLogger.set_all_level(Config.log_level);

  logger.info("github release downloader");
  logger.info(format("version: %s", VersionInfo.VersionInfo.VersionString));

  void package_json_file_callback(string op, string v)
  {
    logger.trace(format("specified --package option. package.json ==> %s", v));
    Config.config_filepath = v;
  }

  void loglevel_callback(string op)
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

  void version_callback()
  {
    writefln("github_release_dl %s", VersionInfo.VersionInfo.VersionString);
    exit(0);
  }

  auto getopt_result = getopt(args, 
      "trace"     , "set log level to trace"                    , &loglevel_callback, 
      "info"      , "set log level to info"                     , &loglevel_callback, 
      "warn"      , "set log level to warn"                     , &loglevel_callback, 
      "warning"   , "set log level to warn"                     , &loglevel_callback, 
      "error"     , "set log level to error"                    , &loglevel_callback, 
      "critical"  , "set log level to critical"                 , &loglevel_callback, 
      "fatal"     , "set log level to fatal"                    , &loglevel_callback,
      "package|p" , "load specified alternative package.json"   , &package_json_file_callback,
      "version"   , "show version"                              , &version_callback
    );
  if (getopt_result.helpWanted)
  {
    defaultGetoptPrinter("option help", getopt_result.options);
    exit(255);
  }

  auto package_configure = new PackageConfigure.PackageConfigure(Config.config_filepath);
  package_configure.load();
  foreach (i, p; package_configure.packages)
  {
    auto info = p.info;

    auto repository = info.repository;
    auto install = info.install;
    auto filename = info.filename;
    const auto destination = info.destination;
    const auto rename = info.rename;

    auto github = new GitHub.GitHub();
    JSONValue[] res_doc = github.get_releases(repository);

    auto latest_release = res_doc[0];
    JSONValue[string] e = latest_release.object;
    const auto published_at = PackageConfigure.PackageConfigure.string_to_datetime(e["published_at"].str);
    JSONValue[] assets = e["assets"].array;
    foreach (a; assets)
    {
      JSONValue[string] n = a.object;
      string name = n["name"].str;

      string dir = "tmp";
      const auto match = matchFirst(name, filename);

      // | match | newer | !exists | download |
      // |-------|-------|---------|----------|
      // | false | false | false   | false    |
      // | false | false | true    | false    |
      // | false | true  | false   | false    |
      // | false | true  | true    | false    |
      // | true  | false | false   | false    |
      // | true  | false | true    | true     |
      // | true  | true  | false   | true     |
      // | true  | true  | true    | true     |
      if (!match)
      {
        continue;
      }

      logger.trace(name);

      string dl_dest_path = buildPath(dir, name);
      if (!(install > published_at || !exists(dl_dest_path)))
      {
        break;
      }

      FileUtils.mkdir_if_not_exists(dir);

      string download_url = n["browser_download_url"].str;
      github.download(download_url, dl_dest_path);

      auto extract_to = destination.length > 0 ? destination : dir;
      FileUtils.mkdir_if_not_exists(extract_to);

      const auto file_type = FileUtils.analyze(dl_dest_path);
      logger.trace(format("file_type = %s", file_type));
      auto result = false;
      switch (file_type)
      {
      case FileUtils.FileType.Zip:
        logger.trace(format("zip dir: %s", FileUtils.dirname_zip(dl_dest_path)));
        if (rename.length > 0)
        {
          // extract to BaseDirectory
          result = FileUtils.extract_zip(dl_dest_path, dir);
          auto from_path = buildPath(dir, FileUtils.dirname_zip(dl_dest_path));
          auto to_path = buildPath(destination, rename);
          logger.trace(format("from = %s, to=%s", from_path, to_path));
          FileUtils.move_recurse(from_path, to_path);
        }
        else
        {
          result = FileUtils.extract_zip(dl_dest_path, extract_to);
        }
        break;
      case FileUtils.FileType.Exe:
        // fall through
      case FileUtils.FileType.Msi:
        result = FileUtils.execute(dl_dest_path, "");
        break;
      default:
        // download only
        result = true;
        break;
      }
    }

    package_configure.packages[i].info.install = published_at;
  }

  package_configure.save();
}
