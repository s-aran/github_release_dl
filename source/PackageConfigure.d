module PackageConfigure;

import std.stdio;
import std.string;
import std.json;
import std.file;
import std.datetime.date : DateTime;
import std.array : join, replace;

struct PackageInfo
{
  string repository;
  DateTime install;
  string filename;
  string destination;
  string rename;
  bool installer;
  bool extract;
}

struct Package
{
  string name;
  PackageInfo info;
}

class PackageConfigure
{
  private string path;
  Package[] packages;

  this(string filepath)
  {
    this.path = filepath;
  }

  void load()
  {
    if (!exists(this.path) || !isFile(this.path))
    {
      throw new Exception("File not found: " ~ this.path);
    }

    auto file = File(this.path, "rb");
    auto content = file.rawRead(new char[file.size]);
    file.close();

    auto json = parseJSON(content).object;
    this.build(json);
  }

  void save()
  {
    if (!exists(this.path) || !isFile(this.path))
    {
      throw new Exception("File not found: " ~ this.path);
    }

    auto file = new File(this.path, "w");
    auto json = this.to_json(this.packages);
    file.write(json.toPrettyString());
    file.close();
  }

  private void build(JSONValue[string] document)
  {
    foreach (key, value; document)
    {
      JSONValue[string] item = value.object;
      string repository = item["repository"].str;

      string install_str = "";
      if ("install" in item)
      {
        install_str = item["install"].str;
      }
      DateTime install = this.string_to_datetime(install_str);
      string filename = item["filename"].str;

      string destination = "";
      if ("destination" in item)
      {
        destination = item["destination"].str;
      }

      string rename = "";
      if ("rename" in item)
      {
        rename = item["rename"].str;
      }

      bool installer = false;
      if (auto _installer = "installer" in item)
      {
        installer =  _installer.type() == JSONType.true_;
      }

      bool extract = true;
      if (auto _extract = "extract" in item)
      {
        extract = _extract.type() == JSONType.true_;
      }

      auto info = PackageInfo(repository, install, filename, destination, rename, installer, extract);
      auto pkg = Package(key, info);
      this.packages ~= pkg;
    }
  }

  private JSONValue to_json(Package[] packages)
  {
    auto result = JSONValue((JSONValue[string]).init);

    foreach (p; packages)
    {
      auto info = p.info;

      auto item = JSONValue((JSONValue[string]).init);
      item["repository"] = info.repository;
      item["install"] = info.install.toISOExtString();
      item["filename"] = info.filename;
      item["destination"] = info.destination;
      if (info.rename.length > 0)
      {
        item["rename"] = info.rename;
      }
      item["installer"] = info.installer;
      item["extract"] = info.extract;

      result[p.name] = item;
    }

    return result;
  }

  static DateTime string_to_datetime(string s)
  {
    // remove 'Z' (YYYY-MM-DDThh:mm:ssZ -> YYYY-MM-DDThh:mm:ss)
    return s.length > 0 ? DateTime.fromISOExtString(s.replace("Z", "")) : DateTime();
  }
}
