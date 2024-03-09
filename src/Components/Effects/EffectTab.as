class EffectTab : Tab {
    EffectTab(TabGroup@ p, const string &in name, const string &in icon) {
        super(p, name, icon);
    }

    // this can be ignored if you override the getters and setters for _IsActive
    protected bool __IsActive = false;

    bool get__IsActive() {
        return __IsActive;
    }
    protected void set__IsActive(bool v) {
        __IsActive = v;
    }

    const string get_DisplayIconAndName() override property {
        if (_IsActive) {
            return "\\$af0\\$s" + Tab::get_DisplayIconAndName();
        }
        return Tab::get_DisplayIconAndName();
    }

    const string get_DisplayIcon() override property {
        if (_IsActive) {
            return "\\$af0\\$s" + tabIcon;
        }
        return tabIcon;
    }
}


class MultiEffectTab : EffectTab {
    MultiEffectTab(TabGroup@ p, const string &in name, const string &in icon) {
        super(p, name, icon);
    }

    bool get__IsActive() override property {
        return Children.AnyActive();
    }
    // set__IsActive does nothing for this type of tab
}
