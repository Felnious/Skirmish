#include "../define.as"
#include "../unit.as"
#include "../helpers/generic_helpers.as"

namespace Military {

	IUnitTask@ AiMakeTask(CCircuitUnit@ u)
	{
		IUnitTask@ t = null;

		RoleConfig@ cfg = (Global::profileController is null) ? null : Global::profileController.RoleCfg;
		if (cfg !is null && cfg.MilitaryAiMakeTaskHandler !is null) {
			@t = cfg.MilitaryAiMakeTaskHandler(u);
		}
		else {
			@t = aiMilitaryMgr.DefaultMakeTask(u);
		}

		return t;
	}

	void AiTaskAdded(IUnitTask@ task)
	{

	}

	void AiTaskRemoved(IUnitTask@ task, bool done)
	{
		// if (done == false) {
		// 	SmrtLog("SMRT: AiTaskRemoved " + task);
		// }
		
	}

	void AiUnitAdded(CCircuitUnit@ unit, Unit::UseAs usage)
	{
		// Delegate to role-specific handler if registered
		RoleConfig@ cfg = (Global::profileController is null) ? null : Global::profileController.RoleCfg;
		if (cfg !is null && cfg.MilitaryAiUnitAdded !is null) {
			cfg.MilitaryAiUnitAdded(unit, usage);
		}
	}

	void AiUnitRemoved(CCircuitUnit@ unit, Unit::UseAs usage)
	{
		// Delegate to role-specific handler if registered
		RoleConfig@ cfg = (Global::profileController is null) ? null : Global::profileController.RoleCfg;
		if (cfg !is null && cfg.MilitaryAiUnitRemoved !is null) {
			cfg.MilitaryAiUnitRemoved(unit, usage);
		}
	}

	void AiLoad(IStream& istream)
	{
	}

	void AiSave(OStream& ostream)
	{
	}

	void AiMakeDefence(int cluster, const AIFloat3& in pos)
	{
		RoleConfig@ cfg = (Global::profileController is null) ? null : Global::profileController.RoleCfg;
		if(cfg !is null && cfg.AiMakeDefenceHandler !is null) {
			cfg.AiMakeDefenceHandler(cluster, pos);
		} else {
			if ((ai.frame > 10 * MINUTE)
			|| (aiEconomyMgr.metal.income > 10.f)
			|| (aiEnemyMgr.mobileThreat > 0.f))
			{
				GenericHelpers::LogUtil("Military::AiMakeDefence", 4);
				aiMilitaryMgr.DefaultMakeDefence(cluster, pos);
			}
		}
		//AiLog("SMRT: Frame - " + ai.frame);
		// if ((ai.frame > 10 * MINUTE)
		// 	|| (aiEconomyMgr.metal.income > 10.f)
		// 	|| (aiEnemyMgr.mobileThreat > 0.f))
		// {
		// 	GenericHelpers::LogUtil("Military::AiMakeDefence", 4);
		// 	aiMilitaryMgr.DefaultMakeDefence(cluster, pos);
		// }
	}

	/*
	* anti-air threat threshold;
	* air factories will stop production when AA threat exceeds
	*/
	// FIXME: Remove/replace, deprecated.
	bool AiIsAirValid()
	{
		RoleConfig@ cfg = (Global::profileController is null) ? null : Global::profileController.RoleCfg;
		if(cfg !is null && cfg.AiIsAirValidHandler !is null) {
			return cfg.AiIsAirValidHandler();
		} else {
			bool isAirValid = aiEnemyMgr.GetEnemyThreat(Unit::Role::AA.type) <= 90000.f;
			GenericHelpers::LogUtil("AiIsAirValid: " + isAirValid, 2);
			return isAirValid;
		}	
	}

}  // namespace Military