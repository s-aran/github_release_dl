module FileUtils;

import std.stdio;
import std.file;
import std.path;
import std.zip;
import std.array;
import std.process;

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
  if (!exists(path) || !isFile(path))
  {
    return false;
  }

  auto zip = new ZipArchive(read(path));
  foreach (name, am; zip.directory)
  {
    if (am.expandedSize == 0 && am.crc32 == 0)
    {
      // Directory
      mkdirRecurse(name);
      writefln("directory: %s", name);
    }
    else
    {
      auto extract_dest = buildPath(to, name);

      writefln(" ... %s", name);
      auto p = dirName(extract_dest);
      if (!exists(p))
      {
        mkdirRecurse(p);
      }

      auto f = File(extract_dest, "wb");
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

void rename(string from, string to)
{
  rename(from, to);
}
