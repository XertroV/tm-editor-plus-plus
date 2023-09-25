class EffectTab : Tab {
    EffectTab(TabGroup@ p, const string &in name, const string &in icon) {
        super(p, name, icon);
    }

    protected bool __IsActive = false;

    bool get__IsActive() {
        return __IsActive;
    }
    protected void set__IsActive(bool v) {
        __IsActive = v;
    }

    const string get_DisplayIconAndName() override property {
        if (_IsActive) {
            return "\\$af0\\$s" + tabIconAndName;
        }
        return tabIconAndName;
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
