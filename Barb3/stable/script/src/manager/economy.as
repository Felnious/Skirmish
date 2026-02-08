#include "../define.as"
#include "../helpers/generic_helpers.as"
#include "../global.as"
#include "../types/role_config.as"

// void OpenStrategy(const CCircuitDef@ facDef, const AIFloat3& in pos)
// {
// 	GenericHelpers::LogUtil("EC2OpenStrategy called for factory: " + facDef.GetName() + " at position: " + pos.x + ", " + pos.z, 1);
// }

namespace Economy {

	// To not reset army requirement on factory switch, @see Factory::AiIsSwitchAllowed
	bool isSwitchAssist = false;

	void AiLoad(IStream& istream)
	{
	}

	void AiSave(OStream& ostream)
	{
	}

	/*
	* struct SResourceInfo {
	*   const float current;
	*   const float storage;
	*   const float pull;
	*   const float income;
	* }
	*/
	void AiUpdateEconomy()
	{
		const SResourceInfo@ metal = aiEconomyMgr.metal;
		const SResourceInfo@ energy = aiEconomyMgr.energy;
		
		Global::Economy::MetalIncome = metal.income;
		Global::Economy::EnergyIncome = energy.income;
		Global::Economy::MetalCurrent = metal.current;
		Global::Economy::EnergyCurrent = energy.current;
		Global::Economy::MetalStorage = metal.storage;
		Global::Economy::EnergyStorage = energy.storage;

		// Update sliding-window minima trackers (10-second window)
		_UpdateSlidingMinima(ai.frame, metal.income, energy.income);

		aiEconomyMgr.isMetalEmpty = metal.current < metal.storage * 0.2f;
		aiEconomyMgr.isMetalFull = metal.current > metal.storage * 0.8f;
		aiEconomyMgr.isEnergyEmpty = energy.current < energy.storage * 0.1f;
		if (aiEconomyMgr.isMetalEmpty) {
			GenericHelpers::LogUtil("Metal Empty", 2);
			aiEconomyMgr.isEnergyStalling = aiEconomyMgr.isEnergyEmpty
				|| ((energy.income < energy.pull) && (energy.current < energy.storage * 0.3f));
		} else {
			aiEconomyMgr.isEnergyStalling = aiEconomyMgr.isEnergyEmpty
				|| ((energy.income < energy.pull) && (energy.current < energy.storage * 0.4f));
		}
		// NOTE: Default energy-to-metal conversion TeamRulesParam "mmLevel" = 0.75
		aiEconomyMgr.isEnergyFull = energy.current > energy.storage * 0.88f;

		// isSwitchAssist = isSwitchAssist && aiFactoryMgr.isAssistRequired;
		//aiFactoryMgr.isAssistRequired = false;
		// 	|| ((metal.current > metal.storage * 0.2f) && !aiEconomyMgr.isEnergyStalling);

		// Then allow role-specific adjustments
		RoleConfig@ cfg = (Global::profileController is null) ? null : Global::profileController.RoleCfg;
		if (cfg !is null && cfg.EconomyUpdateHandler !is null) {
			cfg.EconomyUpdateHandler();
		}
	}

	// Resource getters (expose current resource info handles)
	const SResourceInfo@ GetMetalResource()
	{
		return aiEconomyMgr.metal;
	}

	const SResourceInfo@ GetEnergyResource()
	{
		return aiEconomyMgr.energy;
	}

	// Convenience getters for frequently used values
	float GetMetalIncome()
	{
		return aiEconomyMgr.metal.income;
	}

	float GetEnergyIncome()
	{
		return aiEconomyMgr.energy.income;
	}

	/**************************************
	 * Rolling 10-second minimums (metal/energy)
	 * - Maintains monotonic deques per resource for O(1) amortized updates
	 * - Window length = 10 * SECOND frames
	 **************************************/

	// Small monotonic queue utility for sliding minimums
	class _SlidingMinQueue {
		array<int> frames;   // sample frame indices (monotonic increasing)
		array<float> values; // corresponding values; monotone non-decreasing across queue
		uint head;

		_SlidingMinQueue() { head = 0; }

		void push(int frameIdx, float v, int windowFrames) {
			// Maintain monotonicity by popping larger-or-equal values from the back
			while (values.length() > head) {
				uint backIdx = values.length() - 1;
				if (values[backIdx] >= v) {
					values.removeLast();
					frames.removeLast();
				} else {
					break;
				}
			}
			frames.insertLast(frameIdx);
			values.insertLast(v);
			// Drop out-of-window samples from the front
			int threshold = frameIdx - windowFrames;
			while (values.length() > head && frames[head] <= threshold) {
				head++;
			}
			// Compact occasionally to avoid unbounded head growth
			if (int(head) > 512 && int(head) * 2 > int(frames.length())) {
				_compact();
			}
		}

		float getMin(int frameIdx, int windowFrames, float fallback) {
			int threshold = frameIdx - windowFrames;
			while (values.length() > head && frames[head] <= threshold) {
				head++;
			}
			if (values.length() <= head) return fallback;
			return values[head];
		}

		void _compact() {
			array<int> nf; nf.reserve(frames.length() - head);
			array<float> nv; nv.reserve(values.length() - head);
			for (uint i = head; i < frames.length(); ++i) {
				nf.insertLast(frames[i]);
				nv.insertLast(values[i]);
			}
			frames = nf;
			values = nv;
			head = 0;
		}
	}

	// Shared window length (frames)
	const int _WINDOW_10S_FRAMES = 10 * SECOND;
	_SlidingMinQueue _metalMin10s;
	_SlidingMinQueue _energyMin10s;

	void _UpdateSlidingMinima(int frameIdx, float metalIncome, float energyIncome)
	{
		_metalMin10s.push(frameIdx, metalIncome, _WINDOW_10S_FRAMES);
		_energyMin10s.push(frameIdx, energyIncome, _WINDOW_10S_FRAMES);
	}

	// Public getters: minimum income over the last 10 seconds (frame-based window)
	float GetMinMetalIncomeLast10s()
	{
		// Fallback to current income if window queue is empty
		return _metalMin10s.getMin(ai.frame, _WINDOW_10S_FRAMES, aiEconomyMgr.metal.income);
	}

	float GetMinEnergyIncomeLast10s()
	{
		return _energyMin10s.getMin(ai.frame, _WINDOW_10S_FRAMES, aiEconomyMgr.energy.income);
	}

	// Centralized placement anchors for economy-related structures
	AIFloat3 GetEnergyCenter()
	{
		GenericHelpers::LogUtil("[ECONOMY] Enter GetEnergyCenter", 4);
		return Global::Map::StartPos;
	}

	AIFloat3 GetEnergyConverterCenter()
	{
		GenericHelpers::LogUtil("[ECONOMY] Enter GetEnergyConverterCenter", 4);
		return Global::Map::StartPos;
	}

}  // namespace Economy


