//#include "profile.as"
#include "role_config.as"

funcdef void MainUpdateDelegate();

class ProfileController {  

    //Profile _profile;
    RoleConfig@ RoleCfg; // cached selected role configuration


    ProfileController() {}

    void MainUpdate() {
        if (RoleCfg !is null && RoleCfg.MainUpdateHandler !is null) {
            RoleCfg.MainUpdateHandler();
        }
    }

}