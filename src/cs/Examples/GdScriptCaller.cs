using System;
using System.Linq;
using DreamerHeroines.Data;
using DreamerHeroines.Systems;
using Godot;

namespace DreamerHeroines.Examples
{
    /// <summary>
    /// GDScript 调用 C# 示例
    /// 这个类展示了如何从 GDScript 调用 C# 的方法
    /// </summary>
    public partial class GdScriptCaller : Node
    {
        #region GDScript Callable Methods
        // 这些方法使用 [Callable] 特性（在 Godot 4.x 中使用普通 public 方法即可）

        /// <summary>
        /// 保存游戏 - 供 GDScript 调用
        /// GDScript: $GdScriptCaller.save_game(slot_index)
        /// </summary>
        public void SaveGame(int slotIndex)
        {
            GD.Print($"[C#] SaveGame called from GDScript with slot: {slotIndex}");
            SaveManager.Instance.SaveToSlot(slotIndex);
        }

        /// <summary>
        /// 加载游戏 - 供 GDScript 调用
        /// GDScript: $GdScriptCaller.load_game(slot_index)
        /// </summary>
        public void LoadGame(int slotIndex)
        {
            GD.Print($"[C#] LoadGame called from GDScript with slot: {slotIndex}");
            SaveManager.Instance.LoadFromSlot(slotIndex);
        }

        /// <summary>
        /// 获取存档摘要 - 供 GDScript 调用
        /// GDScript: var summary = $GdScriptCaller.get_save_summary(slot_index)
        /// </summary>
        public Godot.Collections.Dictionary GetSaveSummary(int slotIndex)
        {
            GD.Print($"[C#] GetSaveSummary called from GDScript for slot: {slotIndex}");
            var summary = SaveManager.Instance.GetSaveSummary(slotIndex);

            // 转换为 Godot Dictionary
            var dict = new Godot.Collections.Dictionary
            {
                ["slot_index"] = summary.SlotIndex,
                ["display_name"] = summary.DisplayName,
                ["level"] = summary.Level,
                ["play_time"] = summary.PlayTime,
                ["formatted_time"] = summary.GetFormattedPlayTime(),
                ["last_saved"] = summary.LastSavedAt.ToString("yyyy-MM-dd HH:mm"),
                ["is_empty"] = summary.IsEmpty,
            };

            return dict;
        }

        /// <summary>
        /// 获取所有存档摘要 - 供 GDScript 调用
        /// GDScript: var summaries = $GdScriptCaller.get_all_save_summaries()
        /// </summary>
        public Godot.Collections.Array GetAllSaveSummaries()
        {
            GD.Print("[C#] GetAllSaveSummaries called from GDScript");
            var summaries = SaveManager.Instance.GetAllSaveSummaries();
            var array = new Godot.Collections.Array();

            foreach (var summary in summaries)
            {
                var dict = new Godot.Collections.Dictionary
                {
                    ["slot_index"] = summary.SlotIndex,
                    ["display_name"] = summary.DisplayName,
                    ["level"] = summary.Level,
                    ["play_time"] = summary.PlayTime,
                    ["formatted_time"] = summary.GetFormattedPlayTime(),
                    ["is_empty"] = summary.IsEmpty,
                };
                array.Add(dict);
            }

            return array;
        }

        /// <summary>
        /// 创建新存档 - 供 GDScript 调用
        /// GDScript: $GdScriptCaller.create_new_save(slot_index, "My Save")
        /// </summary>
        public void CreateNewSave(int slotIndex, string displayName)
        {
            GD.Print($"[C#] CreateNewSave called from GDScript: slot={slotIndex}, name={displayName}");
            SaveManager.Instance.CreateNewSave(slotIndex, displayName);
        }

        /// <summary>
        /// 删除存档 - 供 GDScript 调用
        /// GDScript: $GdScriptCaller.delete_save(slot_index)
        /// </summary>
        public bool DeleteSave(int slotIndex)
        {
            GD.Print($"[C#] DeleteSave called from GDScript for slot: {slotIndex}");
            return SaveManager.Instance.DeleteSave(slotIndex);
        }

        /// <summary>
        /// 检查存档槽是否有存档 - 供 GDScript 调用
        /// GDScript: var has_save = $GdScriptCaller.has_save_in_slot(slot_index)
        /// </summary>
        public bool HasSaveInSlot(int slotIndex)
        {
            return SaveManager.Instance.HasSaveInSlot(slotIndex);
        }

        /// <summary>
        /// 切换游戏状态 - 供 GDScript 调用
        /// GDScript: $GdScriptCaller.change_game_state("Playing")
        /// </summary>
        public void ChangeGameState(string stateName)
        {
            GD.Print($"[C#] ChangeGameState called from GDScript: {stateName}");

            if (Enum.TryParse<GameState>(stateName, true, out var state))
            {
                GameStateManager.Instance.ChangeState(state);
            }
            else
            {
                GD.PushError($"[C#] Invalid game state: {stateName}");
            }
        }

        /// <summary>
        /// 获取当前游戏状态 - 供 GDScript 调用
        /// GDScript: var state = $GdScriptCaller.get_current_game_state()
        /// </summary>
        public string GetCurrentGameState()
        {
            return GameStateManager.Instance.CurrentState.ToString();
        }

        /// <summary>
        /// 暂停/恢复游戏 - 供 GDScript 调用
        /// GDScript: $GdScriptCaller.toggle_pause()
        /// </summary>
        public void TogglePause()
        {
            GD.Print("[C#] TogglePause called from GDScript");
            GameStateManager.Instance.TogglePause();
        }

        /// <summary>
        /// 获取玩家数据 - 供 GDScript 调用
        /// GDScript: var player_data = $GdScriptCaller.get_player_data()
        /// </summary>
        public Godot.Collections.Dictionary GetPlayerData()
        {
            var playerData = SaveManager.Instance.GetPlayerData();

            if (playerData == null)
            {
                return new Godot.Collections.Dictionary();
            }

            return new Godot.Collections.Dictionary
            {
                ["player_name"] = playerData.PlayerName,
                ["level"] = playerData.Level,
                ["experience"] = playerData.Experience,
                ["experience_to_next"] = playerData.ExperienceToNextLevel,
                ["experience_progress"] = playerData.ExperienceProgress,
                ["gold"] = playerData.Gold,
                ["gems"] = playerData.Gems,
                ["total_play_time"] = playerData.TotalPlayTime,
                ["formatted_play_time"] = playerData.GetFormattedPlayTime(),
                ["unlocked_weapons"] = new Godot.Collections.Array(
                    playerData.UnlockedWeapons.Select(weapon => Variant.From(weapon))
                ),
                ["completed_levels"] = new Godot.Collections.Array(
                    playerData.CompletedLevels.Select(level => Variant.From(level))
                ),
            };
        }

        /// <summary>
        /// 更新玩家金币 - 供 GDScript 调用
        /// GDScript: $GdScriptCaller.add_gold(100)
        /// </summary>
        public void AddGold(int amount)
        {
            GD.Print($"[C#] AddGold called from GDScript: {amount}");
            var playerData = SaveManager.Instance.GetPlayerData();
            if (playerData != null)
            {
                playerData.AddGold(amount);
                SaveManager.Instance.UpdatePlayerData(playerData);
            }
        }

        /// <summary>
        /// 添加经验值 - 供 GDScript 调用
        /// GDScript: var leveled_up = $GdScriptCaller.add_experience(500)
        /// </summary>
        public bool AddExperience(int amount)
        {
            GD.Print($"[C#] AddExperience called from GDScript: {amount}");
            var playerData = SaveManager.Instance.GetPlayerData();
            if (playerData != null)
            {
                bool leveledUp = playerData.AddExperience(amount);
                SaveManager.Instance.UpdatePlayerData(playerData);
                return leveledUp;
            }
            return false;
        }

        /// <summary>
        /// 解锁武器 - 供 GDScript 调用
        /// GDScript: $GdScriptCaller.unlock_weapon("weapon_rifle")
        /// </summary>
        public bool UnlockWeapon(string weaponId)
        {
            GD.Print($"[C#] UnlockWeapon called from GDScript: {weaponId}");
            var playerData = SaveManager.Instance.GetPlayerData();
            if (playerData != null)
            {
                bool unlocked = playerData.UnlockWeapon(weaponId);
                if (unlocked)
                {
                    SaveManager.Instance.UpdatePlayerData(playerData);
                }
                return unlocked;
            }
            return false;
        }

        /// <summary>
        /// 检查武器是否已解锁 - 供 GDScript 调用
        /// GDScript: var is_unlocked = $GdScriptCaller.is_weapon_unlocked("weapon_rifle")
        /// </summary>
        public bool IsWeaponUnlocked(string weaponId)
        {
            var playerData = SaveManager.Instance.GetPlayerData();
            return playerData?.IsWeaponUnlocked(weaponId) ?? false;
        }

        /// <summary>
        /// 完成关卡 - 供 GDScript 调用
        /// GDScript: $GdScriptCaller.complete_level("level_1")
        /// </summary>
        public bool CompleteLevel(string levelId)
        {
            GD.Print($"[C#] CompleteLevel called from GDScript: {levelId}");
            var playerData = SaveManager.Instance.GetPlayerData();
            if (playerData != null)
            {
                bool completed = playerData.CompleteLevel(levelId);
                if (completed)
                {
                    SaveManager.Instance.UpdatePlayerData(playerData);
                }
                return completed;
            }
            return false;
        }

        /// <summary>
        /// 记录武器击杀 - 供 GDScript 调用
        /// GDScript: $GdScriptCaller.record_weapon_kill("weapon_rifle")
        /// </summary>
        public void RecordWeaponKill(string weaponId)
        {
            var playerData = SaveManager.Instance.GetPlayerData();
            if (playerData != null)
            {
                playerData.RecordWeaponKill(weaponId);
                SaveManager.Instance.UpdatePlayerData(playerData);
            }
        }

        /// <summary>
        /// 获取武器击杀统计 - 供 GDScript 调用
        /// GDScript: var kills = $GdScriptCaller.get_weapon_kills()
        /// </summary>
        public Godot.Collections.Dictionary GetWeaponKills()
        {
            var playerData = SaveManager.Instance.GetPlayerData();
            var dict = new Godot.Collections.Dictionary();

            if (playerData?.WeaponKills != null)
            {
                foreach (var kvp in playerData.WeaponKills)
                {
                    dict[kvp.Key] = kvp.Value;
                }
            }

            return dict;
        }

        /// <summary>
        /// 获取总击杀数 - 供 GDScript 调用
        /// GDScript: var total_kills = $GdScriptCaller.get_total_kills()
        /// </summary>
        public int GetTotalKills()
        {
            return SaveManager.Instance.GetPlayerData()?.Stats.TotalKills ?? 0;
        }

        /// <summary>
        /// 触发自动保存 - 供 GDScript 调用
        /// GDScript: $GdScriptCaller.trigger_auto_save()
        /// </summary>
        public void TriggerAutoSave()
        {
            GD.Print("[C#] TriggerAutoSave called from GDScript");
            SaveManager.Instance.ResetAutoSaveTimer();
        }

        /// <summary>
        /// 设置自动保存开关 - 供 GDScript 调用
        /// GDScript: $GdScriptCaller.set_auto_save_enabled(true)
        /// </summary>
        public void SetAutoSaveEnabled(bool enabled)
        {
            GD.Print($"[C#] SetAutoSaveEnabled called from GDScript: {enabled}");
            SaveManager.Instance.AutoSaveEnabled = enabled;
        }

        /// <summary>
        /// 获取自动保存状态 - 供 GDScript 调用
        /// GDScript: var enabled = $GdScriptCaller.is_auto_save_enabled()
        /// </summary>
        public bool IsAutoSaveEnabled()
        {
            return SaveManager.Instance.AutoSaveEnabled;
        }

        /// <summary>
        /// 获取距离下次自动保存的时间 - 供 GDScript 调用
        /// GDScript: var time = $GdScriptCaller.get_time_until_auto_save()
        /// </summary>
        public double GetTimeUntilAutoSave()
        {
            return SaveManager.Instance.TimeUntilAutoSave;
        }
        #endregion

        #region Signals for GDScript
        // 这些信号可以被 GDScript 连接

        /// <summary>
        /// 当游戏保存完成时触发
        /// </summary>
        [Signal]
        public delegate void SaveCompletedEventHandler(int slot, bool success);

        /// <summary>
        /// 当游戏加载完成时触发
        /// </summary>
        [Signal]
        public delegate void LoadCompletedEventHandler(int slot, bool success);

        /// <summary>
        /// 当玩家升级时触发
        /// </summary>
        [Signal]
        public delegate void PlayerLeveledUpEventHandler(int newLevel);

        /// <summary>
        /// 当玩家数据更新时触发
        /// </summary>
        [Signal]
        public delegate void PlayerDataUpdatedEventHandler(Godot.Collections.Dictionary playerData);

        public override void _Ready()
        {
            // 连接 SaveManager 的信号到本地信号
            SaveManager.Instance.SaveCompleted += OnSaveCompleted;
            SaveManager.Instance.LoadCompleted += OnLoadCompleted;
        }

        private void OnSaveCompleted(int slot, bool success)
        {
            EmitSignal(SignalName.SaveCompleted, slot, success);
        }

        private void OnLoadCompleted(int slot, bool success)
        {
            EmitSignal(SignalName.LoadCompleted, slot, success);
        }
        #endregion
    }
}
