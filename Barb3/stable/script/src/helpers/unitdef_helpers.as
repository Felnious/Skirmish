#include "../define.as"
#include "../global.as"
#include "../types/ai_role.as"
#include "../types/start_spot.as" // for StartSpot & AIFloat3
#include "../types/terrain.as" // for Terrain enum
#include "generic_helpers.as" // for LogUtil

namespace UnitDefHelpers {

    // Simple whitespace check and trim helpers (Angelscript has no built-in trim)
    // Use numeric ASCII codes: space(32), tab(9), newline(10), carriage return(13)
    bool _IsSpace(const uint c) {
        return c == 32 || c == 9 || c == 10 || c == 13;
    }
    string _Trim(const string &in s) {
        uint len = s.length();
        if (len == 0) return s;
        uint i = 0, j = len - 1;
        while (i < len && _IsSpace(s[i])) { ++i; }
        while (j > i && _IsSpace(s[j])) { --j; }
        if (i >= len) return "";
        return s.substr(i, j - i + 1);
    }

    void SetIgnoreFor(const array<string>@ names, bool ignore = true)
    {
        if (names is null) return;

        uint changed = 0, missing = 0, skippedEmpty = 0, skippedDup = 0;
        dictionary seen;
        for (uint i = 0; i < names.length(); ++i) {
            string n = _Trim(names[i]);
            if (n.length() == 0) { ++skippedEmpty; continue; }
            int _;
            if (seen.get(n, _)) { ++skippedDup; continue; }
            seen.set(n, 1);

            CCircuitDef@ def = ai.GetCircuitDef(n);
            if (def is null) {
                // Try lowercase as many defs are lowercase internally
                @def = ai.GetCircuitDef(n.toLower());
            }
            if (def is null) {
                ++missing;
                GenericHelpers::LogUtil("SetIgnoreFor: unitdef not found: '" + n + "'", 2);
                continue;
            }

            bool was = def.IsIgnore();
            def.SetIgnore(ignore);
            if (was != ignore) {
                ++changed;
            }
        }

    GenericHelpers::LogUtil("SetIgnoreFor: updated=" + changed + ", missing=" + missing + ", skippedEmpty=" + skippedEmpty + ", skippedDup=" + skippedDup + ", input=" + names.length(), 3);
    }

    // Core helper: enable=true adds if missing; enable=false removes if present
    void ApplyAttrFor(const array<string>@ names, const string &in attrName, bool enable)
    {
        if (names is null) return;

        TypeMask attr = aiAttrMasker.GetTypeMask(attrName);
        if (attr.type < 0) {
            GenericHelpers::LogUtil("ApplyAttrFor: unknown attribute '" + attrName + "'", 2);
            return;
        }

        uint changed = 0, skipped = 0, missing = 0, skippedEmpty = 0, skippedDup = 0;
        dictionary seen;
        for (uint i = 0; i < names.length(); ++i) {
            string n = _Trim(names[i]);
            if (n.length() == 0) { ++skippedEmpty; continue; }
            int _;
            if (seen.get(n, _)) { ++skippedDup; continue; }
            seen.set(n, 1);

            CCircuitDef@ def = ai.GetCircuitDef(n);
            if (def is null) {
                // Most defs are lowercase internally
                @def = ai.GetCircuitDef(n.toLower());
            }
            if (def is null) {
                ++missing;
                GenericHelpers::LogUtil("ApplyAttrFor: unitdef not found: '" + n + "'", 2);
                continue;
            }

            bool hasAttr = def.IsAttrAny(attr.mask);
            if (enable) {
                if (!hasAttr) {
                    def.AddAttribute(attr.type);
                    ++changed;
                    GenericHelpers::LogUtil("ApplyAttrFor: added '" + attrName + "' to '" + n + "'", 2);
                } else {
                    ++skipped;
                    GenericHelpers::LogUtil("ApplyAttrFor: already had '" + attrName + "' on '" + n + "', skipped", 2);
                }
            } else {
                if (hasAttr) {
                    def.DelAttribute(attr.type);
                    ++changed;
                    GenericHelpers::LogUtil("ApplyAttrFor: removed '" + attrName + "' from '" + n + "'", 2);
                } else {
                    ++skipped;
                    GenericHelpers::LogUtil("ApplyAttrFor: no '" + attrName + "' on '" + n + "', skipped", 2);
                }
            }
        }

      GenericHelpers::LogUtil("ApplyAttrFor('" + attrName + "', enable=" + (enable ? "true" : "false") +
          "): changed=" + changed + ", skippedAttr=" + skipped + ", missing=" + missing + ", skippedEmpty=" + skippedEmpty + ", skippedDup=" + skippedDup + ", input=" + names.length(), 3);
    }

    // Ensure the attribute is present on each named unitdef
    void AddAttrFor(const array<string>@ names, const string &in attrName)
    {
        ApplyAttrFor(names, attrName, true);
    }

    // Ensure the attribute is absent on each named unitdef
    void RemoveNoAttrFor(const array<string>@ names, const string &in attrName)
    {
        ApplyAttrFor(names, attrName, false);
    }
    
    void SetMainRoleFor(const array<string>@ names, const string &in roleName) {
        Type roleType = aiRoleMasker.GetTypeMask(roleName).type;
        for (uint i = 0; i < names.length(); ++i) {
            CCircuitDef@ def = ai.GetCircuitDef(names[i]);
            if (def !is null) {
                def.SetMainRole(roleType);
                GenericHelpers::LogUtil("SetMainRoleFor: set role '" + roleName + "' for '" + names[i] + "'", 2);
            }
        }
    }

    int GetUnitDefCount(string unitDefName) {
        CCircuitDef@ def = ai.GetCircuitDef(unitDefName);
        if (def is null) {
            // Most defs are lowercase internally
            @def = ai.GetCircuitDef(unitDefName.toLower());
        }
        if (def is null) {
            GenericHelpers::LogUtil("GetUnitDefCount: unitdef not found: '" + unitDefName + "'", 2);
        }
        int result = (def is null ? -1 : def.count);
        GenericHelpers::LogUtil("GetUnitDefCount: '" + unitDefName + "' count=" + result, 2);
        return result;
    }

    // Sums the total count across an array of unit def names.
    // Trims inputs and attempts lowercase fallback for lookups.
    // Missing defs contribute 0 to the sum.
    int SumUnitDefCounts(const array<string>@ unitDefNames)
    {
        if (unitDefNames is null) return 0;
        int total = 0;
        for (uint i = 0; i < unitDefNames.length(); ++i) {
            string n = _Trim(unitDefNames[i]);
            if (n.length() == 0) continue;

            CCircuitDef@ def = ai.GetCircuitDef(n);
            if (def is null) {
                @def = ai.GetCircuitDef(n.toLower());
            }
            if (def is null) {
                GenericHelpers::LogUtil("SumUnitDefCounts: unitdef not found: '" + n + "'", 2);
                continue;
            }
            total += def.count;
        }
        GenericHelpers::LogUtil("SumUnitDefCounts: names=" + unitDefNames.length() + " total=" + total, 3);
        return total;
    }

}