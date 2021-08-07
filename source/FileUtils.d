module FileUtils;

import std.stdio;
import std.file;
import std.path;
import std.zip;
import std.array;
import std.process;
import std.format;

import Logger;


private const string BaseDirectory = "tmp";

enum FileType
{
  Unknown = 0,
  Zip,
  Exe,
  Rpm,
  Deb,
  Msi,
}

private auto get_logger()
{
  return EzLogger.get_logger("file");
}

bool mkdir_if_not_exists(string pathname)
{
  if (!exists(pathname))
  {
    mkdirRecurse(pathname);
  }
  return true;
}

string dirname_zip(string path)
{
  if (!exists(path) || !isFile(path))
  {
    return "";
  }

  string result = "";
  auto zip = new ZipArchive(read(path));
  foreach (name, am; zip.directory)
  {
    if (am.expandedSize == 0 && am.crc32 == 0)
    {
      writefln("directory: %s", name);
      auto l = pathSplitter(name);
      result = l.array[0];
      break;
    }
  }

  return result;
}

bool extract_zip(string path, string to)
{
  auto logger = get_logger();

  if (!exists(path) || !isFile(path))
  {
    logger.info(format("extract: %s is not exists or not file", path));
    return false;
  }

  logger.info(format("extract %s to %s", path, to));

  auto zip = new ZipArchive(read(path));
  foreach (name, am; zip.directory)
  {
    auto extract_dest = buildPath(to, name);

    if (am.expandedSize == 0 && am.crc32 == 0)
    {
      logger.trace(format("directory: %s", extract_dest));
      mkdirRecurse(extract_dest);
    }
    else
    {

      logger.info(format(" ... %s", name));
      auto p = dirName(extract_dest);
      if (!exists(p))
      {
        logger.info(format("make directory: %s", p));
        mkdirRecurse(p);
      }

      logger.trace(format("=====> %s", extract_dest));

      auto f = File(extract_dest, "wb+");
      f.rawWrite(zip.expand(am));
      f.close();

      if (am.expandedData.length != am.expandedSize)
      {
        return false;
      }
    }
  }

  return true;
}

bool execute(string path, string params = "")
{
  auto result = executeShell(path);
  return result.status == 0;
}

FileType analyze(string path)
{
  const auto ReadBytes = 15;

  auto f = File(path, "rb");
  auto buf = f.rawRead(new ubyte[ReadBytes]);
  f.close();

  // Debian package
  if (buf[0] == 0x21 && buf[1] == 0x3C && buf[2] == 0x61 && buf[3] == 0x72
      && buf[4] == 0x68 && buf[5] == 0x3E && buf[6] == 0x0A)
  {
    return FileType.Deb;
  }

  // Redhat package
  if (buf[0] == 0xED && buf[1] == 0xAB && buf[2] == 0xEE && buf[3] == 0xDB)
  {
    return FileType.Rpm;
  }

  // Msi package (compound file binary format)
  if (buf[0] == 0xD0 && buf[1] == 0xCF && buf[2] == 0x11 && buf[3] == 0xE0
      && buf[4] == 0xA1 && buf[5] == 0xB1 && buf[6] == 0x1A && buf[7] == 0xE1)
  {
    return FileType.Msi;
  }

  // Exe
  if (buf[0] == 0x4D && buf[1] == 0x5A)
  {
    return FileType.Exe;
  }

  // Zip
  if (buf[0] == 0x50 && buf[1] == 0x4B && buf[2] == 0x03 && buf[3] == 0x04)
  {
    return FileType.Zip;
  }

  return FileType.Unknown;
}

static bool move_recurse(string from, string to)
{
  auto logger = get_logger();

  logger.trace(format("move %s -> %s", from, to));

  foreach (nm; dirEntries(from, SpanMode.depth))
  {
    auto to_dir_path = buildPath(pathSplitter(nm).array[2 .. $ - 1]); // directory path
    auto to_file_path = buildPath(pathSplitter(nm).array[2 .. $]); // file path

    auto move_dest_dir = buildPath(to, to_dir_path);
    if (!exists(move_dest_dir))
    {
      mkdirRecurse(move_dest_dir);
    }

    if (isFile(nm))
    {
      auto move_dest_path = buildPath(to, to_file_path);
      logger.trace(format("%s -> %s", nm, move_dest_path));
      copy(nm, move_dest_path);
    }
  }
  rmdirRecurse(from);

  return true;
}


DirEntry[] get_files_with_sort_by_lastmodified(string path)
{
    import std.algorithm;
    // TODO:
    //    1. List files contain tmp/
    //    2. sort last update asc
    //    3. pattern match
    //    4. extract
    alias comp = (x, y) => x.timeLastModified() > y.timeLastModified();
    DirEntry[] files = dirEntries(path, SpanMode.breadth).array;
    return files.sort!(comp).release;
}
    
