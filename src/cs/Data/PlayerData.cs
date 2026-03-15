using Godot;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace StrikeForceLike.Data
{
    /// <summary>
    /// 玩家数据类 - 包含玩家进度、等级、装备等信息
    /// 实现INotifyPropertyChanged接口以支持数据绑定
    /// </summary>
    public class PlayerData : INotifyPropertyChanged
    {
        #region Fields
        private int _level = 1;
        private int _experience = 0;
        private int _gold = 0;
        private int _gems = 0;
        private string _playerName = "Player";
        private int _totalPlayTime = 0;
        private DateTime _lastSaveTime = DateTime.Now;
        private List<string> _unlockedWeapons = new List<string>();
        private List<string> _completedLevels = new List<string>();
        private Dictionary<string, int> _weaponKills = new Dictionary<string, int>();
        private PlayerStats _stats = new PlayerStats();
        private PlayerSettings _settings = new PlayerSettings();
        #endregion

        #region Properties
        /// <summary>
        /// 玩家等级
        /// </summary>
        public int Level
        {
            get => _level;
            set
            {
                if (_level != value)
                {
                    _level = value;
                    OnPropertyChanged();
                    OnPropertyChanged(nameof(ExperienceToNextLevel));
                }
            }
        }

        /// <summary>
        /// 当前经验值
        /// </summary>
        public int Experience
        {
            get => _experience;
            set
            {
                if (_experience != value)
                {
                    _experience = value;
                    OnPropertyChanged();
                    OnPropertyChanged(nameof(ExperienceToNextLevel));
                    CheckLevelUp();
                }
            }
        }

        /// <summary>
        /// 金币数量
        /// </summary>
        public int Gold
        {
            get => _gold;
            set
            {
                if (_gold != value)
                {
                    _gold = value;
                    OnPropertyChanged();
                }
            }
        }

        /// <summary>
        /// 宝石数量（高级货币）
        /// </summary>
        public int Gems
        {
            get => _gems;
            set
            {
                if (_gems != value)
                {
                    _gems = value;
                    OnPropertyChanged();
                }
            }
        }

        /// <summary>
        /// 玩家名称
        /// </summary>
        public string PlayerName
        {
            get => _playerName;
            set
            {
                if (_playerName != value)
                {
                    _playerName = value;
                    OnPropertyChanged();
                }
            }
        }

        /// <summary>
        /// 总游戏时间（秒）
        /// </summary>
        public int TotalPlayTime
        {
            get => _totalPlayTime;
            set
            {
                if (_totalPlayTime != value)
                {
                    _totalPlayTime = value;
                    OnPropertyChanged();
                }
            }
        }

        /// <summary>
        /// 上次存档时间
        /// </summary>
        public DateTime LastSaveTime
        {
            get => _lastSaveTime;
            set
            {
                if (_lastSaveTime != value)
                {
                    _lastSaveTime = value;
                    OnPropertyChanged();
                }
            }
        }

        /// <summary>
        /// 已解锁的武器列表
        /// </summary>
        public List<string> UnlockedWeapons
        {
            get => _unlockedWeapons;
            set
            {
                _unlockedWeapons = value ?? new List<string>();
                OnPropertyChanged();
            }
        }

        /// <summary>
        /// 已完成的关卡列表
        /// </summary>
        public List<string> CompletedLevels
        {
            get => _completedLevels;
            set
            {
                _completedLevels = value ?? new List<string>();
                OnPropertyChanged();
            }
        }

        /// <summary>
        /// 各武器击杀数统计
        /// </summary>
        public Dictionary<string, int> WeaponKills
        {
            get => _weaponKills;
            set
            {
                _weaponKills = value ?? new Dictionary<string, int>();
                OnPropertyChanged();
            }
        }

        /// <summary>
        /// 玩家属性统计
        /// </summary>
        public PlayerStats Stats
        {
            get => _stats;
            set
            {
                _stats = value ?? new PlayerStats();
                OnPropertyChanged();
            }
        }

        /// <summary>
        /// 玩家设置
        /// </summary>
        public PlayerSettings Settings
        {
            get => _settings;
            set
            {
                _settings = value ?? new PlayerSettings();
                OnPropertyChanged();
            }
        }

        /// <summary>
        /// 升到下一级所需经验
        /// </summary>
        public int ExperienceToNextLevel => CalculateExperienceForLevel(_level + 1) - _experience;

        /// <summary>
        /// 当前经验进度（0-1）
        /// </summary>
        public float ExperienceProgress
        {
            get
            {
                int currentLevelExp = CalculateExperienceForLevel(_level);
                int nextLevelExp = CalculateExperienceForLevel(_level + 1);
                int levelExp = nextLevelExp - currentLevelExp;
                int currentExpInLevel = _experience - currentLevelExp;
                return levelExp > 0 ? (float)currentExpInLevel / levelExp : 0f;
            }
        }
        #endregion

        #region Events
        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged([CallerMemberName] string propertyName = "")
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
        #endregion

        #region Public Methods
        /// <summary>
        /// 添加经验值
        /// </summary>
        /// <param name="amount">经验值数量</param>
        /// <returns>是否升级</returns>
        public bool AddExperience(int amount)
        {
            int oldLevel = _level;
            Experience += amount;
            return _level > oldLevel;
        }

        /// <summary>
        /// 添加金币
        /// </summary>
        public void AddGold(int amount)
        {
            Gold = Math.Max(0, _gold + amount);
        }

        /// <summary>
        /// 消耗金币
        /// </summary>
        /// <returns>是否成功</returns>
        public bool SpendGold(int amount)
        {
            if (_gold >= amount)
            {
                Gold -= amount;
                return true;
            }
            return false;
        }

        /// <summary>
        /// 添加宝石
        /// </summary>
        public void AddGems(int amount)
        {
            Gems = Math.Max(0, _gems + amount);
        }

        /// <summary>
        /// 消耗宝石
        /// </summary>
        /// <returns>是否成功</returns>
        public bool SpendGems(int amount)
        {
            if (_gems >= amount)
            {
                Gems -= amount;
                return true;
            }
            return false;
        }

        /// <summary>
        /// 解锁武器
        /// </summary>
        public bool UnlockWeapon(string weaponId)
        {
            if (!_unlockedWeapons.Contains(weaponId))
            {
                _unlockedWeapons.Add(weaponId);
                OnPropertyChanged(nameof(UnlockedWeapons));
                return true;
            }
            return false;
        }

        /// <summary>
        /// 检查武器是否已解锁
        /// </summary>
        public bool IsWeaponUnlocked(string weaponId)
        {
            return _unlockedWeapons.Contains(weaponId);
        }

        /// <summary>
        /// 完成关卡
        /// </summary>
        public bool CompleteLevel(string levelId)
        {
            if (!_completedLevels.Contains(levelId))
            {
                _completedLevels.Add(levelId);
                OnPropertyChanged(nameof(CompletedLevels));
                return true;
            }
            return false;
        }

        /// <summary>
        /// 检查关卡是否已完成
        /// </summary>
        public bool IsLevelCompleted(string levelId)
        {
            return _completedLevels.Contains(levelId);
        }

        /// <summary>
        /// 记录武器击杀
        /// </summary>
        public void RecordWeaponKill(string weaponId)
        {
            if (!_weaponKills.ContainsKey(weaponId))
            {
                _weaponKills[weaponId] = 0;
            }
            _weaponKills[weaponId]++;
            Stats.TotalKills++;
            OnPropertyChanged(nameof(WeaponKills));
        }

        /// <summary>
        /// 增加游戏时间
        /// </summary>
        public void AddPlayTime(int seconds)
        {
            TotalPlayTime += seconds;
        }

        /// <summary>
        /// 获取格式化后的游戏时间
        /// </summary>
        public string GetFormattedPlayTime()
        {
            TimeSpan time = TimeSpan.FromSeconds(_totalPlayTime);
            if (time.TotalHours >= 1)
            {
                return $"{time.Hours}h {time.Minutes}m";
            }
            return $"{time.Minutes}m {time.Seconds}s";
        }

        /// <summary>
        /// 重置为新游戏状态
        /// </summary>
        public void ResetToNewGame()
        {
            Level = 1;
            Experience = 0;
            Gold = 0;
            Gems = 0;
            TotalPlayTime = 0;
            _unlockedWeapons.Clear();
            _completedLevels.Clear();
            _weaponKills.Clear();
            Stats = new PlayerStats();
            LastSaveTime = DateTime.Now;
        }

        /// <summary>
        /// 创建深拷贝
        /// </summary>
        public PlayerData Clone()
        {
            return new PlayerData
            {
                Level = this.Level,
                Experience = this.Experience,
                Gold = this.Gold,
                Gems = this.Gems,
                PlayerName = this.PlayerName,
                TotalPlayTime = this.TotalPlayTime,
                LastSaveTime = this.LastSaveTime,
                UnlockedWeapons = new List<string>(this.UnlockedWeapons),
                CompletedLevels = new List<string>(this.CompletedLevels),
                WeaponKills = new Dictionary<string, int>(this.WeaponKills),
                Stats = this.Stats.Clone(),
                Settings = this.Settings.Clone()
            };
        }
        #endregion

        #region Private Methods
        private void CheckLevelUp()
        {
            while (_experience >= CalculateExperienceForLevel(_level + 1))
            {
                _level++;
                OnPropertyChanged(nameof(Level));
                OnLevelUp?.Invoke(this, _level);
            }
        }

        private int CalculateExperienceForLevel(int level)
        {
            // 经验公式：100 * level^1.5
            return (int)(100 * Math.Pow(level, 1.5));
        }
        #endregion

        #region Events
        public event EventHandler<int>? OnLevelUp;
        #endregion
    }

    /// <summary>
    /// 玩家属性统计
    /// </summary>
    public class PlayerStats : INotifyPropertyChanged
    {
        private int _totalKills = 0;
        private int _totalDeaths = 0;
        private int _shotsFired = 0;
        private int _shotsHit = 0;
        private float _totalDamageDealt = 0f;
        private float _totalDamageTaken = 0f;
        private int _missionsCompleted = 0;
        private int _missionsFailed = 0;

        public int TotalKills
        {
            get => _totalKills;
            set { _totalKills = value; OnPropertyChanged(); }
        }

        public int TotalDeaths
        {
            get => _totalDeaths;
            set { _totalDeaths = value; OnPropertyChanged(); }
        }

        public int ShotsFired
        {
            get => _shotsFired;
            set { _shotsFired = value; OnPropertyChanged(); OnPropertyChanged(nameof(Accuracy)); }
        }

        public int ShotsHit
        {
            get => _shotsHit;
            set { _shotsHit = value; OnPropertyChanged(); OnPropertyChanged(nameof(Accuracy)); }
        }

        public float TotalDamageDealt
        {
            get => _totalDamageDealt;
            set { _totalDamageDealt = value; OnPropertyChanged(); }
        }

        public float TotalDamageTaken
        {
            get => _totalDamageTaken;
            set { _totalDamageTaken = value; OnPropertyChanged(); }
        }

        public int MissionsCompleted
        {
            get => _missionsCompleted;
            set { _missionsCompleted = value; OnPropertyChanged(); }
        }

        public int MissionsFailed
        {
            get => _missionsFailed;
            set { _missionsFailed = value; OnPropertyChanged(); }
        }

        /// <summary>
        /// 命中率（0-1）
        /// </summary>
        public float Accuracy => _shotsFired > 0 ? (float)_shotsHit / _shotsFired : 0f;

        /// <summary>
        /// K/D比率
        /// </summary>
        public float KDRatio => _totalDeaths > 0 ? (float)_totalKills / _totalDeaths : _totalKills;

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged([CallerMemberName] string propertyName = "")
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }

        public PlayerStats Clone()
        {
            return new PlayerStats
            {
                TotalKills = this.TotalKills,
                TotalDeaths = this.TotalDeaths,
                ShotsFired = this.ShotsFired,
                ShotsHit = this.ShotsHit,
                TotalDamageDealt = this.TotalDamageDealt,
                TotalDamageTaken = this.TotalDamageTaken,
                MissionsCompleted = this.MissionsCompleted,
                MissionsFailed = this.MissionsFailed
            };
        }
    }

    /// <summary>
    /// 玩家设置
    /// </summary>
    public class PlayerSettings : INotifyPropertyChanged
    {
        private float _masterVolume = 1.0f;
        private float _musicVolume = 0.8f;
        private float _sfxVolume = 1.0f;
        private float _mouseSensitivity = 1.0f;
        private bool _invertMouseY = false;
        private bool _showDamageNumbers = true;
        private bool _screenShake = true;
        private int _targetFrameRate = 60;
        private bool _vsync = true;
        private bool _fullscreen = false;

        public float MasterVolume
        {
            get => _masterVolume;
            set { _masterVolume = value; OnPropertyChanged(); }
        }

        public float MusicVolume
        {
            get => _musicVolume;
            set { _musicVolume = value; OnPropertyChanged(); }
        }

        public float SFXVolume
        {
            get => _sfxVolume;
            set { _sfxVolume = value; OnPropertyChanged(); }
        }

        public float MouseSensitivity
        {
            get => _mouseSensitivity;
            set { _mouseSensitivity = value; OnPropertyChanged(); }
        }

        public bool InvertMouseY
        {
            get => _invertMouseY;
            set { _invertMouseY = value; OnPropertyChanged(); }
        }

        public bool ShowDamageNumbers
        {
            get => _showDamageNumbers;
            set { _showDamageNumbers = value; OnPropertyChanged(); }
        }

        public bool ScreenShake
        {
            get => _screenShake;
            set { _screenShake = value; OnPropertyChanged(); }
        }

        public int TargetFrameRate
        {
            get => _targetFrameRate;
            set { _targetFrameRate = value; OnPropertyChanged(); }
        }

        public bool VSync
        {
            get => _vsync;
            set { _vsync = value; OnPropertyChanged(); }
        }

        public bool Fullscreen
        {
            get => _fullscreen;
            set { _fullscreen = value; OnPropertyChanged(); }
        }

        public event PropertyChangedEventHandler? PropertyChanged;

        protected virtual void OnPropertyChanged([CallerMemberName] string propertyName = "")
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }

        public PlayerSettings Clone()
        {
            return new PlayerSettings
            {
                MasterVolume = this.MasterVolume,
                MusicVolume = this.MusicVolume,
                SFXVolume = this.SFXVolume,
                MouseSensitivity = this.MouseSensitivity,
                InvertMouseY = this.InvertMouseY,
                ShowDamageNumbers = this.ShowDamageNumbers,
                ScreenShake = this.ScreenShake,
                TargetFrameRate = this.TargetFrameRate,
                VSync = this.VSync,
                Fullscreen = this.Fullscreen
            };
        }
    }
}
