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
import std.format;
import core.stdc.stdlib: exit;

import Args;
import Config: Config, ConfigFile;
import VersionInfo;
import GitHub;
import PackageConfigure;
import FileUtils;
import Logger;


void main(string[] args)
{
  auto logger = EzLogger.get_logger("main");

  logger.info("github release downloader");
  logger.info(format("version: %s", VersionInfo.VersionInfo.VersionString));

  EzLogger.set_all_level(Config.log_level);
  Arguments.analyze(args);

  ConfigFile config_file = new ConfigFile("config.json");
  config_file.load();

  DirEntry[] files = [];
  if (Config.install_only && !Config.download_only)
  {
    files = FileUtils.get_files_with_sort_by_lastmodified(Config.download_dest);
    // foreach (DirEntry e; list)
    // {
    //   writefln("%s / %s", e.name(), e.timeLastModified());
    // }
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
    const auto installer = info.installer;

    auto extract_to = destination.length > 0 ? destination : Config.download_dest;

    if (Config.download_only || (!Config.download_only && !Config.install_only))
    {
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

        const auto match = matchFirst(name, filename);

        // | match | newer | !exists | download |
        // |-------|-------|---------|----------|
        // | x     | x     | x       | x        |
        // | x     | x     | o       | x        |
        // | x     | o     | x       | x        |
        // | x     | o     | o       | x        |
        // | o     | x     | x       | x        |
        // | o     | x     | o       | o        |
        // | o     | o     | x       | o        |
        // | o     | o     | o       | o        |
        if (!match)
        {
          continue;
        }

        logger.trace(name);

        string dl_dest_path = buildPath(Config.download_dest, name);
        if (!(install > published_at || !exists(dl_dest_path)))
        {
          break;
        }

        FileUtils.mkdir_if_not_exists(Config.download_dest);

        string download_url = n["browser_download_url"].str;
        github.download(download_url, dl_dest_path);

        if (!Config.download_only && !Config.install_only)
        {
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
              result = FileUtils.extract_zip(dl_dest_path, Config.download_dest);
              auto from_path = buildPath(Config.download_dest, FileUtils.dirname_zip(dl_dest_path));
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
            result = installer ? FileUtils.execute(dl_dest_path, "") : true;
            break;
          default:
            // download only
            result = true;
            break;
          }

          package_configure.packages[i].info.install = published_at;
        }
      }
    }

    if (Config.install_only && !Config.download_only)
    {
      logger.trace(format("asset regex => %s", filename));
      foreach (DirEntry e; files)
      {
        logger.trace(format("file => %s", baseName(e.name)));
        const auto match = matchFirst(baseName(e.name), filename);
        if (!match)
        {
          continue;
        }

        const auto file_type = FileUtils.analyze(e.name);
        logger.trace(format("file_type = %s", file_type));
        auto result = false;
        switch (file_type)
        {
          case FileUtils.FileType.Zip:
            logger.trace(format("zip dir: %s", FileUtils.dirname_zip(e.name)));
            if (rename.length > 0)
            {
              // extract to BaseDirectory
              result = FileUtils.extract_zip(e.name, Config.download_dest);
              auto from_path = buildPath(Config.download_dest, FileUtils.dirname_zip(e.name));
              auto to_path = buildPath(destination, rename);
              logger.trace(format("from = %s, to=%s", from_path, to_path));
              FileUtils.move_recurse(from_path, to_path);
            }
            else
            {
              result = FileUtils.extract_zip(e.name, extract_to);
            }
            break;
          case FileUtils.FileType.Exe:
            // fall through
          case FileUtils.FileType.Msi:
            result = installer ? FileUtils.execute(e.name, "") : true;
            break;
          default:
            // download only
            result = true;
            break;
        }

        break;
      }
    }
  }

  package_configure.save();
}
