module libmenu;

import std.stdio; 
import std.file;
import std.string;
import std.array;
import std.algorithm.searching : startsWith;
import std.process : environment;
import std.conv : to;
import core.stdc.locale : setlocale, LC_ALL, LC_MESSAGES;
import std.algorithm.searching : find, countUntil;
import std.algorithm.sorting : sort;

// XDG dirs
// read each dir
//   read .desktop files
//     name
//     name[ru]
//     name[ru.RU]
//     exec
//     icon
//     terminal
//     category
// read categories
//   read .desktop files
//     name
//     name[ru]
//     name[ru.RU]
//     icon
// group by name
// save categories
//   .cache/libmenu/categories
// save applications
//   .cache/libmenu/applications
//
// check timestamp
//   .cache/libmenu/categories
//   .cache/libmenu/applications
// compare with XDG directories
// compare with XDG directories/files.desktop
// if defferent
//   read .cache/libmenu/categories
//   read .cache/libmenu/applications
// else
//   go read each dir

// sysconfdir       -                                         default: /etc
// HOME
// XDG_DATA_HOME    - base.                                   default: $HOME/.local/share
// XDG_CONFIG_HOME  - config.                                 default: $HOME/.config
// XDG_DATA_DIRS    - дополняет XDG_DATA_HOME.   dir:dir:dir. default: /usr/local/share/:/usr/share/
// XDG_CONFIG_DIRS  - дополняет XDG_CONFIG_HOME. dir:dir:dir. default: /etc/xdg
// XDG_CACHE_HOME   - cache.                                  default: $HOME/.cache
//
// default access: 0700

/*
class ApplicationFie {
    void read_application_file(string filename) {
        // open file
        // read line
        // wait [Desktop Entry]
        // wait Name
        // wait Name[ru]
        // wait Name[ru_RU]
        // wait GenericName
        // wait GenericName[ru]
        // wait GenericName[ru_RU]
        // wait Exec
        // wait Icon
        // wait category
        // wait Terminal
        // wait Type
        // save to struct {name, name_locale, exec, icon, category, terminal, keywords}
        
        // Categories = GNOME;Utility;
        // OnlyShowIn = GNOME;
        // Type = Application
        // Terminal = true
        
       File file = File(filename, "r"); 
       
       while (!file.eof()) { 
          string line = file.readln().chomp().stripLeft(); 
          
          if (line.startsWith("#")) {
              // continue
          } else 
          if (line.startsWith("Name")) {
              //
          } else 
          if (line.startsWith("Name[ru]")) {
              //
          } else 
       }
          
       file.close();    
    }
    
    void read_multistring() {
        // s;s;s;
    }
}
*/

Locale syslocale;

struct Menu {
    Applications applications;
    Categories   categories;
    //Autostart    autostart;
   
    void read() {
        applications.read();
        categories.read();                
    }
            
    string[] registered_categories() {
        string[] r;
        
        r ~= "AudioVideo";
        r ~= "Audio";
        r ~= "Video";
        r ~= "Development";
        r ~= "Education";
        r ~= "Game";
        r ~= "Graphics";
        r ~= "Network";
        r ~= "Office";
        r ~= "Science";
        r ~= "Settings";
        r ~= "System";
        r ~= "Utility";
        
        return r;
    }
    
    string[] reserved_categories() {
        string[] r;
        
        r ~= "Screensaver";
        r ~= "TrayIcon";
        r ~= "Applet";
        r ~= "Shell";

        return r;
    }
    
    string[] get_category(string s) {
        auto splitted = s.split(";");
        return splitted;
    }
    
    void save_to_cache() {
        //
    }
    
    unittest {
        syslocale.from_string(to!string(setlocale (LC_MESSAGES, "")));

        Menu m;
        m.read();
        assert(!m.applications.apps.empty);
    }
}

struct Applications {
    ApplicationFile[string] apps; // grouped by name
    
    void read() {
        ApplicationFolders app_folders;
        app_folders._init();

        foreach (folder; app_folders.folders) {
            foreach (string name; dirEntries(folder, SpanMode.breadth)) {
                if (name.endsWith(".desktop")) {
                    ApplicationFile a;
                    a.from_file(name);

                    if (!a.Name.empty && !a.Hidden && !a.NoDisplay && !a.DBusActivatable) {
                        apps[a.Name] = a;
                    }
                }
            }
        }
    }
}

// $XDG_CONFIG_DIRS/menus/${XDG_MENU_PREFIX}applications.menu - XML
// $XDG_CONFIG_DIRS/menus/applications-merged/
// $XDG_DATA_DIRS/applications/
// $XDG_DATA_DIRS/desktop-directories/

// // XDG_DATA_HOME/applications
// // XDG_DATA_DIRS/applications
struct ApplicationFolders {
    string[] folders;
    
    void _init() {
        folders ~= "/usr/share/applications";
    }
}

struct ApplicationsFolder {
    string folder = "/usr/share/applications";
    
    void read() {
        foreach (string name; dirEntries(folder, SpanMode.breadth)) {
            if (name.endsWith(".desktop")) {
                ApplicationFile af;
                af.from_file(name);
            }
        }
    }
    
    unittest {
        ApplicationsFolder af;
        af.read();
    }
}

struct ApplicationFile {
    // read file
    // parse file
    //   parse each line
    // save to struct {name, name_lc, exec, icon, category, in_terminal, keywords}
    string Name;
    string NameLC;
    string GenericName;
    string GenericNameLC;
    string Exec;
    string Path;
    string Icon;
    string Categories;
    bool   Terminal;
    string Keywords;
    string Type; // Application | Link | Directory
    bool   NoDisplay;
    bool   Hidden;
    string OnlyShowIn;
    string NotShowIn;
    bool   DBusActivatable;
    string TryExec;
    string Actions;
    string MimeType;
    string Implements;
    bool   StartupNotify;
    string StartupWMClass;
    string URL;
    
    void from_file(string filename) {
        File file = File(filename, "r"); 
       
        while (!file.eof()) { 
            string line = file.readln().chomp();
            
            if (line.startsWith("[") && line != "[Desktop Entry]") {
                break;
            }
            
            parse_line(line);
        }
        
        file.close();    
    }
    
    void parse_line(string line) {
        DesktopItemLine l;
        
        bool res = l.from_string(line);
        
        if (res) {
            if (l.key == "Name") {
                if (l.value_type == DILtype.STRING) {
                    Name = l.value;
                    
                } else 
                if (l.value_type == DILtype.LCSTRING) {
                    NameLC = l.value;
                } 

            } else
            if (l.key == "GenericName") {
                if (l.value_type == DILtype.STRING) {
                    GenericName = l.value;
                    
                } else 
                if (l.value_type == DILtype.LCSTRING) {
                    GenericNameLC = l.value;
                } 

            } else
            if (l.key == "Exec") {
                Exec = l.value;

            } else
            if (l.key == "Icon") {
                Icon = l.value;

            } else
            if (l.key == "Categories") {
                Categories = l.value;

            } else
            if (l.key == "Terminal") {
                Terminal = l.value == "true" ? true : false;

            } else
            if (l.key == "Keywords") {
                Keywords = l.value;

            } else
            if (l.key == "Type") {
                Type = l.value;

            } else
            if (l.key == "NoDisplay") {
                NoDisplay = l.value == "true" ? true : false;

            } else
            if (l.key == "Hidden") {
                Hidden = l.value == "true" ? true : false;

            } else
            if (l.key == "OnlyShowIn") {
                OnlyShowIn = l.value;

            } else
            if (l.key == "NotShowIn") {
                NotShowIn = l.value;

            } else
            if (l.key == "DBusActivatable") {
                DBusActivatable = l.value == "true" ? true : false;

            } else
            if (l.key == "TryExec") {
                TryExec = l.value;

            } else
            if (l.key == "Actions") {
                Actions = l.value;

            } else
            if (l.key == "MimeType") {
                MimeType = l.value;

            } else
            if (l.key == "Implements") {
                Implements = l.value;

            } else
            if (l.key == "StartupNotify") {
                StartupNotify = l.value == "true" ? true : false;

            } else
            if (l.key == "StartupWMClass") {
                StartupWMClass = l.value;

            } else
            if (l.key == "URL") {
                URL = l.value;
            }
        }
      }
      
    unittest {
        ApplicationFile af;
        af.from_file("./test/AcetoneISO.desktop");
        assert(af.Name == "AcetoneISO");
    }
        
    unittest {
        syslocale.from_string(to!string(setlocale (LC_MESSAGES, "")));

        ApplicationFile af;
        af.from_file("./test/Thunar.desktop");
        assert(af.Name == "Thunar File Manager");
        assert(af.NameLC == "Файловый менеджер Thunar");
    }
}

struct Categories {
    CategoryFile[string] cats; // grouped by name
    
    void read() {
        CategoryFolders cat_folders;
        cat_folders._init();

        foreach (folder; cat_folders.folders) {
            foreach (string name; dirEntries(folder, SpanMode.breadth)) {
                if (name.endsWith(".directory")) {
                    CategoryFile c;
                    c.from_file(name);
                    
                    if (!c.Name.empty && c.Type == "Directory") {
                        cats[c.Name] = c;
                    }
                }
            }
        }
    }
}

struct CategoryFolders {
    string[] folders;
    
    void _init() {
        folders ~= "/usr/share/desktop-directories";
    }
}

struct CategoryFile {
    // read file
    // parse file
    //   parse each line
    //   Type = Directory
    // save to struct {name, name_lc, icon}
    string Name;
    string NameLC;
    string Icon;
    string Type;
    
    void from_file(string filename) {
        File file = File(filename, "r"); 
       
        while (!file.eof()) { 
            string line = file.readln().chomp(); 
            parse_line(line);
        }
        
        file.close();    
    }
    
    void parse_line(string line) {
        DesktopItemLine l;
        
        bool res = l.from_string(line);
        if (res) {
            if (l.key == "Name") {
                if (l.value_type == DILtype.STRING) {
                    Name = l.value;
                    
                } else 
                if (l.value_type == DILtype.LCSTRING) {
                    NameLC = l.value;
                } 

            } else
            if (l.key == "Icon") {
                Icon = l.value;

            } else
            if (l.key == "Type") {
                Type = l.value;
            } 
        }
      }

    unittest {
        syslocale.from_string(to!string(setlocale (LC_MESSAGES, "")));

        CategoryFile cf;
        cf.from_file("./test/Development.directory");
        assert(cf.Name == "Programming");
        assert(cf.Icon == "applications-development");
        assert(cf.Type == "Directory");
        
        cf = cf.init;
        cf.from_file("./test/xfce-development.directory");
        assert(cf.Name == "Development");
        assert(cf.NameLC == "Разработка");
        assert(cf.Icon == "applications-development");
        assert(cf.Type == "Directory");
    }
}


enum DILtype {
    NONE,
    COMMENT,
    SECTION,
    STRING,
    LCSTRING,
    BOOLEAN,
    NUMERIC
}

struct DesktopItemLine {
    immutable(char)[] s; // slice of source string
    immutable(char)[] key;
    Locale            locale;
    immutable(char)[] value;
    DILtype           value_type;
    bool              value_boolean;
    float             value_numeric;

    bool from_string(string str) {
        s = str[];

        if (!s.empty) {
            return 
                skip_spaces()   && 
                check_comment() &&
                check_section() &&
                read_name()     && 
                read_locale()   &&
                check_locale()  &&
                skip_spaces()   && 
                read_eq()       && 
                skip_spaces()   && 
                read_value();
        }
        
        return false;
    }

    bool read_name() {
        key = s;
        size_t i;
        
        while (!s.empty 
               && (   s.front >= 'A' && s.front <= 'Z' 
                   || s.front >= 'a' && s.front <= 'z' 
                   || s.front >= '0' && s.front <= '9' 
                   || s.front == '-'))
        {
            s = s[1..$];
            i++;
        }

        if (i) {
            key = key[0..i];
        }
        
        return true;
    }
    
    bool skip_spaces() {
        while (!s.empty && s.front == ' ') {
            s = s[1..$];
        }
        
        return true;
    }
        
    bool check_comment() {
        if (!s.empty && s.front == '#') {
            value_type = DILtype.COMMENT;
            return false;
        }
        
        return true;
    }
    
    bool check_section() {
        if (!s.empty && s.front == '[') {
            value_type = DILtype.SECTION;
            return false;
        }
        
        return true;
    }
    
    bool read_locale() {
        // locale
        // LC_MESSAGES="ru_RU.UTF-8"
        // lang_COUNTRY.ENCODING@MODIFIER
        // ru_RU.UTF-8
        if (s.front == '[') {
            s = s[1..$];
            
            auto locale_length = s.countUntil("]");
            
            if (locale_length != -1) {
                auto res = locale.from_string(s[0..locale_length]);   
                             
                s = s[locale_length+1..$];
                
                return res;
                
            } else {
                return false; // wrong line: without ']'
            }
        
        } else {
            return true; // not localized
        }        
    }

    
    bool compare_locales() {        
        return (locale == syslocale);
    }
    
    bool check_locale() {
        if (!locale.lang.empty || !locale.country.empty || !locale.encoding.empty || !locale.modifier.empty) { // has locale
            // key_lang
            // key_country
            // key_encoding
            // key_modifier            
            //
            // system_locale            
            return compare_locales();
            
        } else {
            return true; // no locale
        }
    }
        
    bool read_eq() {
        if (!s.empty && s.front == '=') {
            s = s[1..$];
            return true;
        }
        
        return false;
    }
    
    bool read_value() {
        // read_string()        // 
        // read_localestring()  // for locale string. UTF-8 
        // read_boolean()       // true | false
        // read_numeric()       // scanf("%f")
        if (!locale.lang.empty || !locale.country.empty || !locale.encoding.empty || !locale.modifier.empty) {
            value_type = DILtype.LCSTRING;
            read_localestring();
            
        } else {
            read_string();

            if (value == "true" || value == "false") {
                value_type = DILtype.BOOLEAN;
                value_boolean = value == "true" ? true : false;
                
            } else
            if (isNumeric(value)) {
                value_numeric = to!float(value);
                value_type = DILtype.NUMERIC;
                
            } else {
                value_type = DILtype.STRING;
            }
        }
        
        return true;
    }
        
    bool read_string() {
        // ASCII
        // \s, \n, \t, \r, \\, \;
        if (!s.empty) {
            value = s[0..$];
        }
        
        return true;
    }
    
    bool read_localestring() {
        // UTF-8
        // \s, \n, \t, \r, \\, \;
        // 
        // [LOCALE]
        // [lang_COUNTRY.ENCODING@MODIFIER]
        //   LC_MESSAGES
        
        //LocaleString ls;
        //ls.parse(s);
        if (!s.empty) {
            value = s[0..$];
        }
        
        return true;
    }
    
    void read_boolean() {
        // true | false
    }
    
    void read_numeric() {
        // scanf("%f")
    } 

    unittest {
        syslocale.from_string(to!string(setlocale (LC_MESSAGES, "")));

        DesktopItemLine l;
        l.from_string("Name=The name");
        assert(l.key == "Name");

        l = l.init;
        l.from_string("Name[ru]=The name");
        assert(l.key == "Name");
        assert(l.locale.lang == "ru");
        assert(l.value == "The name");

        l = l.init;
        l.from_string("Name = The name");
        assert(l.key == "Name");

        l = l.init;
        l.from_string("#Name = The name");
        assert(l.key.empty);

        l = l.init;
        l.from_string("   Name = The name");
        assert(l.key == "Name");

        l = l.init;
        l.from_string("   #Name = The name");
        assert(l.key.empty);

        l = l.init;
        l.from_string("Name=");
        assert(l.key == "Name");
        assert(l.value.empty);

        l = l.init;
        l.from_string("Name[ru_RU]=The name");
        assert(l.key == "Name");
        assert(l.locale.lang == "ru");
        assert(l.locale.country == "RU");

        l = l.init;
        l.from_string("Name[ru_RU.UTF-8]=The name");
        assert(l.key == "Name");
        assert(l.locale.lang == "ru");
        assert(l.locale.country == "RU");
        assert(l.locale.encoding == "UTF-8");

        l = l.init;
        l.from_string("Name[ru_RU.UTF-8@latin]=The name");
        assert(l.key == "Name");
        assert(l.locale.lang == "ru");
        assert(l.locale.country == "RU");
        assert(l.locale.encoding == "UTF-8");
        assert(l.locale.modifier == "latin");

        l = l.init;
        l.from_string("Name=The name");
        assert(l.key == "Name");
        assert(l.value == "The name");

        l = l.init;
        l.from_string("Name[ru]=Название");
        assert(l.key == "Name");
        assert(l.value == "Название");

        l = l.init;
        l.from_string("InTerminal=true");
        assert(l.key == "InTerminal");
        assert(l.value == "true");
        assert(l.value_type == DILtype.BOOLEAN);
        assert(l.value_boolean == true);

        l = l.init;
        l.from_string("Number=0.9");
        assert(l.key == "Number");
        assert(l.value == "0.9");
        assert(l.value_type == DILtype.NUMERIC);
        assert(l.value_numeric == to!float(0.9));

        l = l.init;
        bool res = l.from_string("Name[ru]=Файловый менеджер Thunar");
        assert(res);
        assert(l.value_type == DILtype.LCSTRING);
        assert(l.key == "Name");
        assert(l.value == "Файловый менеджер Thunar");
    }
}

struct Locale {
    immutable(char)[] s;
    immutable(char)[] lang;
    immutable(char)[] country;
    immutable(char)[] encoding;
    immutable(char)[] modifier;

    bool from_string(string str) {
        // locale
        // LC_MESSAGES="ru_RU.UTF-8"
        // lang_COUNTRY.ENCODING@MODIFIER
        // ru_RU.UTF-8
        s = str[];
        return 
            read_locale_lang() &&
            read_locale_country() &&
            read_locale_encoding() &&
            read_locale_modifier();
    }

    bool read_locale_lang() {
        lang = s;
        size_t i;
        
        while (!s.empty 
               && (   s.front >= 'A' && s.front <= 'Z' 
                   || s.front >= 'a' && s.front <= 'z' 
                   || s.front >= '0' && s.front <= '9' 
                   || s.front == '-'))
        {
            s = s[1..$];
            i++;
        }

        if (i) {
            lang = lang[0..i];
        }
        
        return true;
    }
    
    bool read_locale_country() {
        if (!s.empty) {
            if (s.front == '_') {
                s = s[1..$];
                
                country = s;
                size_t i;

                while (!s.empty 
                       && (   s.front >= 'A' && s.front <= 'Z' 
                           //|| s.front >= 'a' && s.front <= 'z' 
                           //|| s.front >= '0' && s.front <= '9' 
                           //|| s.front == '-'
                           ))
                {
                    s = s[1..$];
                    i++;
                }

                if (i) {
                    country = country[0..i];
                }
            }
        }
        
        return true;
    }
    
    bool read_locale_encoding() {
        if (!s.empty) {
            if (s.front == '.') {
                s = s[1..$];
                
                encoding = s;
                size_t i;

                while (!s.empty 
                       && (   s.front >= 'A' && s.front <= 'Z' 
                           || s.front >= 'a' && s.front <= 'z' 
                           || s.front >= '0' && s.front <= '9' 
                           || s.front == '-'
                           ))
                {
                    s = s[1..$];
                    i++;
                }

                if (i) {
                    encoding = encoding[0..i];
                }
            }
        }
            
        return true;
    }
    
    bool read_locale_modifier() {
        if (!s.empty) {
            if (s.front == '@') {
                s = s[1..$];
                
                modifier = s;
                size_t i;

                while (!s.empty 
                       && (   s.front >= 'A' && s.front <= 'Z' 
                           || s.front >= 'a' && s.front <= 'z' 
                           || s.front >= '0' && s.front <= '9' 
                           || s.front == '-'
                           ))
                {
                    s = s[1..$];
                    i++;
                }

                if (i) {
                    modifier = modifier[0..i];
                }
            }
        }
        
        return true;
    }
    
    bool opEquals(Locale b) {
        if (!lang.empty) {
            if (lang != b.lang) {
                return false;
            }
        }

        if (!country.empty) {
            if (country != b.country) {
                return false;
            }
        }

        if (!encoding.empty) {
            if (encoding != b.encoding) {
                return false;
            }
        }

        if (!modifier.empty) {
            if (modifier != b.modifier) {
                return false;
            }
        }

        return true;
    }

    unittest {
        char* loc = setlocale (LC_MESSAGES, "");
        
        Locale l;
        l.from_string(to!string(loc));
        assert(l.lang == "ru");
        assert(l.country == "RU");
        assert(l.encoding == "UTF-8");
        assert(l.modifier.empty);
    }
}
