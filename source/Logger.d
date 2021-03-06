import std.array;
import std.conv;
import std.stdio;
import std.format;
import std.string : fromStringz;
import std.datetime.systime;

class EzLogger
{
  public enum Level
  {
    Trace = 0,
    Info,
    Warn,
    Warning = Warn,
    Error,
    Critical,
    Fatal,
  }

  private static EzLogger[string] instances;

  public static ref EzLogger get_logger(const string module_name)
  {
    if (!(module_name in instances))
    {
      auto level = Level.Info;
      if (instances.length > 0)
      {
        level = instances.values[0].get_level();
      }
      instances[module_name] = new EzLogger(level, module_name);
    }

    return instances[module_name];
  }

  private Level level = Level.Info;
  private string module_name = "";

  this(const Level level, const string module_name)
  {
    this.level = level;
    this.module_name = module_name;
  }

  private static string get_level_string(Level level)
  {
    switch (level)
    {
      case Level.Trace:
        return "Trace";
      case Level.Info:
        return "Info";
      case Level.Warn:
        return "Warn";
      case Level.Error:
        return "Error";
      case Level.Critical:
        return "Critical";
      case Level.Fatal:
        return "Fatal";
      default:
        return "???";
    }
  }

  private static string get_current_datetime(string format_str)
  {
    auto now = Clock.currTime();
    return format_str
      .replace("%y", format("%.4d", now.year))
      .replace("%m", format("%.2d", now.month))
      .replace("%d", format("%.2d", now.day))
      .replace("%H", format("%.2d", now.hour))
      .replace("%M", format("%.2d", now.minute))
      .replace("%S", format("%.2d", now.second));
  }

  private void writeMessage(Level level, string message)
  {
    if (level >= this.level)
    {
      writefln("[%s][%s][%s] %s", get_current_datetime("%y/%m/%d %H:%M:%S"), this.module_name, get_level_string(level), message);
    }
  }

  public Level get_level()
  {
    return this.level;
  }

  public void set_level(Level level)
  {
    this.level = level;
  }

  public static void set_all_level(Level level)
  {      
    foreach (i; instances)
    {
      i.set_level(level);
    }
  }

  public void trace(string message)
  {
    writeMessage(Level.Trace, message);
  }

  public void info(string message)
  {
    writeMessage(Level.Info, message);
  }

  public void warn(string message)
  {
    writeMessage(Level.Warn, message);
  }

  public void error(string message)
  {
    writeMessage(Level.Error, message);
  }

  public void critical(string message)
  {
    writeMessage(Level.Critical, message);
  }

  public void fatal(string message)
  {
    writeMessage(Level.Fatal, message);
  }
}