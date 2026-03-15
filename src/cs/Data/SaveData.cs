using Godot;
using System;
using System.Collections.Generic;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace StrikeForceLike.Data
{
    /// <summary>
    /// 存档数据容器 - 包含所有需要保存的游戏数据
    /// </summary>
    [Serializable]
    public class SaveData
    {
        /// <summary>
        /// 存档版本号，用于兼容性检查
        /// </summary>
        public string Version { get; set; } = "1.0.0";

        /// <summary>
        /// 存档创建时间
        /// </summary>
        public DateTime CreatedAt { get; set; } = DateTime.Now;

        /// <summary>
        /// 最后保存时间
        /// </summary>
        public DateTime LastSavedAt { get; set; } = DateTime.Now;

        /// <summary>
        /// 存档槽索引
        /// </summary>
        public int SlotIndex { get; set; } = 0;

        /// <summary>
        /// 存档显示名称
        /// </summary>
        public string DisplayName { get; set; } = "New Game";

        /// <summary>
        /// 玩家数据
        /// </summary>
        public PlayerSaveData Player { get; set; } = new PlayerSaveData();

        /// <summary>
        /// 游戏进度数据
        /// </summary>
        public ProgressSaveData Progress { get; set; } = new ProgressSaveData();

        /// <summary>
        /// 游戏设置
        /// </summary>
        public SettingsSaveData Settings { get; set; } = new SettingsSaveData();

        /// <summary>
        /// 运行时临时数据（不保存到文件）
        /// </summary>
        [JsonIgnore]
        public Dictionary<string, object> RuntimeData { get; set; } = new Dictionary<string, object>();

        /// <summary>
        /// 创建新的存档数据
        /// </summary>
        public static SaveData CreateNew(int slotIndex, string displayName)
        {
            return new SaveData
            {
                SlotIndex = slotIndex,
                DisplayName = displayName,
                CreatedAt = DateTime.Now,
                LastSavedAt = DateTime.Now,
                Version = "1.0.0",
                Player = new PlayerSaveData(),
                Progress = new ProgressSaveData(),
                Settings = new SettingsSaveData()
            };
        }

        /// <summary>
        /// 更新保存时间
        /// </summary>
        public void UpdateSaveTime()
        {
            LastSavedAt = DateTime.Now;
        }

        /// <summary>
        /// 获取存档摘要信息
        /// </summary>
        public SaveSummary GetSummary()
        {
            return new SaveSummary
            {
                SlotIndex = SlotIndex,
                DisplayName = DisplayName,
                Level = Player.Level,
                PlayTime = Player.TotalPlayTime,
                LastSavedAt = LastSavedAt,
                CurrentLevel = Progress.CurrentLevelId
            };
        }
    }

    /// <summary>
    /// 玩家存档数据
    /// </summary>
    [Serializable]
    public class PlayerSaveData
    {
        public string PlayerName { get; set; } = "Player";
        public int Level { get; set; } = 1;
        public int Experience { get; set; } = 0;
        public int Gold { get; set; } = 0;
        public int Gems { get; set; } = 0;
        public int TotalPlayTime { get; set; } = 0;
        public List<string> UnlockedWeapons { get; set; } = new List<string>();
        public List<string> CompletedLevels { get; set; } = new List<string>();
        public Dictionary<string, int> WeaponKills { get; set; } = new Dictionary<string, int>();
        public PlayerStatsSaveData Stats { get; set; } = new PlayerStatsSaveData();
        public string? CurrentWeapon { get; set; }
        public Dictionary<string, WeaponUpgradeData> WeaponUpgrades { get; set; } = new Dictionary<string, WeaponUpgradeData>();
    }

    /// <summary>
    /// 玩家统计存档数据
    /// </summary>
    [Serializable]
    public class PlayerStatsSaveData
    {
        public int TotalKills { get; set; } = 0;
        public int TotalDeaths { get; set; } = 0;
        public int ShotsFired { get; set; } = 0;
        public int ShotsHit { get; set; } = 0;
        public float TotalDamageDealt { get; set; } = 0f;
        public float TotalDamageTaken { get; set; } = 0f;
        public int MissionsCompleted { get; set; } = 0;
        public int MissionsFailed { get; set; } = 0;
    }

    /// <summary>
    /// 武器升级数据
    /// </summary>
    [Serializable]
    public class WeaponUpgradeData
    {
        public int DamageLevel { get; set; } = 0;
        public int FireRateLevel { get; set; } = 0;
        public int MagazineLevel { get; set; } = 0;
        public int ReloadSpeedLevel { get; set; } = 0;
        public int AccuracyLevel { get; set; } = 0;
    }

    /// <summary>
    /// 游戏进度存档数据
    /// </summary>
    [Serializable]
    public class ProgressSaveData
    {
        public string CurrentLevelId { get; set; } = "level_1";
        public string? CheckPointId { get; set; }
        public Dictionary<string, LevelProgressData> LevelProgress { get; set; } = new Dictionary<string, LevelProgressData>();
        public List<string> UnlockedLevels { get; set; } = new List<string>();
        public Dictionary<string, bool> CollectiblesFound { get; set; } = new Dictionary<string, bool>();
        public Dictionary<string, bool> SecretsFound { get; set; } = new Dictionary<string, bool>();
    }

    /// <summary>
    /// 关卡进度数据
    /// </summary>
    [Serializable]
    public class LevelProgressData
    {
        public bool IsCompleted { get; set; } = false;
        public int BestScore { get; set; } = 0;
        public float BestTime { get; set; } = float.MaxValue;
        public int DeathCount { get; set; } = 0;
        public int Difficulty { get; set; } = 0;
        public List<string> ObjectivesCompleted { get; set; } = new List<string>();
    }

    /// <summary>
    /// 设置存档数据
    /// </summary>
    [Serializable]
    public class SettingsSaveData
    {
        public float MasterVolume { get; set; } = 1.0f;
        public float MusicVolume { get; set; } = 0.8f;
        public float SFXVolume { get; set; } = 1.0f;
        public float MouseSensitivity { get; set; } = 1.0f;
        public bool InvertMouseY { get; set; } = false;
        public bool ShowDamageNumbers { get; set; } = true;
        public bool ScreenShake { get; set; } = true;
        public int TargetFrameRate { get; set; } = 60;
        public bool VSync { get; set; } = true;
        public bool Fullscreen { get; set; } = false;
        public string Language { get; set; } = "zh_CN";
        public Dictionary<string, string> KeyBindings { get; set; } = new Dictionary<string, string>();
    }

    /// <summary>
    /// 存档摘要信息（用于存档列表显示）
    /// </summary>
    public class SaveSummary
    {
        public int SlotIndex { get; set; }
        public string DisplayName { get; set; } = "";
        public int Level { get; set; }
        public int PlayTime { get; set; }
        public DateTime LastSavedAt { get; set; }
        public string? CurrentLevel { get; set; }
        public bool IsEmpty => string.IsNullOrEmpty(DisplayName) || DisplayName == "New Game";

        /// <summary>
        /// 获取格式化后的游戏时间
        /// </summary>
        public string GetFormattedPlayTime()
        {
            TimeSpan time = TimeSpan.FromSeconds(PlayTime);
            if (time.TotalHours >= 1)
            {
                return $"{time.Hours}h {time.Minutes}m";
            }
            return $"{time.Minutes}m {time.Seconds}s";
        }

        /// <summary>
        /// 获取格式化后的保存时间
        /// </summary>
        public string GetFormattedSaveTime()
        {
            TimeSpan timeSinceSave = DateTime.Now - LastSavedAt;
            if (timeSinceSave.TotalDays >= 1)
            {
                return $"{timeSinceSave.Days}天前";
            }
            else if (timeSinceSave.TotalHours >= 1)
            {
                return $"{timeSinceSave.Hours}小时前";
            }
            else if (timeSinceSave.TotalMinutes >= 1)
            {
                return $"{timeSinceSave.Minutes}分钟前";
            }
            return "刚刚";
        }
    }

    /// <summary>
    /// 存档序列化器
    /// </summary>
    public static class SaveSerializer
    {
        private static readonly JsonSerializerOptions _options = new JsonSerializerOptions
        {
            WriteIndented = true,
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
            IncludeFields = true
        };

        /// <summary>
        /// 将存档数据序列化为JSON字符串
        /// </summary>
        public static string Serialize(SaveData data)
        {
            return JsonSerializer.Serialize(data, _options);
        }

        /// <summary>
        /// 从JSON字符串反序列化存档数据
        /// </summary>
        public static SaveData? Deserialize(string json)
        {
            try
            {
                return JsonSerializer.Deserialize<SaveData>(json, _options);
            }
            catch (Exception ex)
            {
                GD.PushError($"Failed to deserialize save data: {ex.Message}");
                return null;
            }
        }

        /// <summary>
        /// 验证存档数据完整性
        /// </summary>
        public static bool Validate(SaveData? data)
        {
            if (data == null) return false;
            if (string.IsNullOrEmpty(data.Version)) return false;
            if (data.Player == null) return false;
            if (data.Progress == null) return false;
            return true;
        }
    }
}
