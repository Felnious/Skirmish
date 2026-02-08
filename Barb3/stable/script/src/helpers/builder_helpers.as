#include "generic_helpers.as"
#include "../global.as"

namespace BuilderHelpers {

    // Determine if a builder should be allowed to initiate base-anchored projects
    bool IsBaseInitiator(CCircuitUnit@ u)
    {
        GenericHelpers::LogUtil("[Builder] Enter IsBaseInitiator", 4);
        // Example: first two base constructors you already track, or any builder with BASE+SOLO
        return u.IsAttrAny(aiAttrMasker.GetTypeMask("base").mask)
            && u.IsAttrAny(aiAttrMasker.GetTypeMask("solo").mask);
    }

} // namespace BuilderHelpers
