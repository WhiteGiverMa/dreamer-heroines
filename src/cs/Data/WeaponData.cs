using System;
using System.Collections.Generic;
using Godot;

namespace DreamerHeroines.Data
{
    /// <summary>
    /// 武器数据定义 - 包含武器的所有属性和行为配置
    /// </summary>
    public class WeaponData
    {
        #region Basic Info
        /// <summary>
        /// 武器唯一ID
        /// </summary>
        public string Id { get; set; } = "";

        /// <summary>
        /// 武器显示名称
        /// </summary>
        public string DisplayName { get; set; } = "Unknown Weapon";

        /// <summary>
        /// 武器描述
        /// </summary>
        public string Description { get; set; } = "";

        /// <summary>
        /// 武器类型
        /// </summary>
        public WeaponType Type { get; set; } = WeaponType.Rifle;

        /// <summary>
        /// 武器稀有度
        /// </summary>
        public WeaponRarity Rarity { get; set; } = WeaponRarity.Common;

        /// <summary>
        /// 武器图标路径
        /// </summary>
        public string IconPath { get; set; } = "";

        /// <summary>
        /// 武器模型/精灵路径
        /// </summary>
        public string ModelPath { get; set; } = "";

        /// <summary>
        /// 解锁所需等级
        /// </summary>
        public int UnlockLevel { get; set; } = 1;

        /// <summary>
        /// 购买价格
        /// </summary>
        public int Price { get; set; } = 0;
        #endregion

        #region Combat Stats
        /// <summary>
        /// 基础伤害
        /// </summary>
        public float BaseDamage { get; set; } = 10f;

        /// <summary>
        /// 射速（每秒发射次数）
        /// </summary>
        public float FireRate { get; set; } = 5f;

        /// <summary>
        /// 弹匣容量
        /// </summary>
        public int MagazineSize { get; set; } = 30;

        /// <summary>
        /// 装弹时间（秒）
        /// </summary>
        public float ReloadTime { get; set; } = 2f;

        /// <summary>
        /// 射程
        /// </summary>
        public float Range { get; set; } = 100f;

        /// <summary>
        /// 子弹速度
        /// </summary>
        public float ProjectileSpeed { get; set; } = 500f;

        /// <summary>
        /// 子弹预制体路径
        /// </summary>
        public string ProjectilePath { get; set; } = "";

        /// <summary>
        /// 射击模式
        /// </summary>
        public FireMode FireMode { get; set; } = FireMode.SemiAuto;

        /// <summary>
        /// 连发数量（Burst模式使用）
        /// </summary>
        public int BurstCount { get; set; } = 3;

        /// <summary>
        /// 连发间隔（Burst模式使用）
        /// </summary>
        public float BurstInterval { get; set; } = 0.1f;
        #endregion

        #region Accuracy & Recoil
        /// <summary>
        /// 基础精准度（0-1，1为完全精准）
        /// </summary>
        public float BaseAccuracy { get; set; } = 0.9f;

        /// <summary>
        /// 移动时精准度惩罚
        /// </summary>
        public float MovingAccuracyPenalty { get; set; } = 0.2f;

        /// <summary>
        /// 连续射击精准度衰减
        /// </summary>
        public float AccuracyDecay { get; set; } = 0.05f;

        /// <summary>
        /// 后坐力垂直分量
        /// </summary>
        public float RecoilVertical { get; set; } = 1f;

        /// <summary>
        /// 后坐力水平分量
        /// </summary>
        public float RecoilHorizontal { get; set; } = 0.3f;

        /// <summary>
        /// 后坐力恢复速度
        /// </summary>
        public float RecoilRecovery { get; set; } = 5f;

        /// <summary>
        /// 枪口上跳角度
        /// </summary>
        public float MuzzleClimb { get; set; } = 2f;
        #endregion

        #region Audio & Visual
        /// <summary>
        /// 射击音效路径
        /// </summary>
        public string FireSoundPath { get; set; } = "";

        /// <summary>
        /// 装弹音效路径
        /// </summary>
        public string ReloadSoundPath { get; set; } = "";

        /// <summary>
        /// 空仓音效路径
        /// </summary>
        public string EmptySoundPath { get; set; } = "";

        /// <summary>
        /// 枪口闪光效果路径
        /// </summary>
        public string MuzzleFlashPath { get; set; } = "";

        /// <summary>
        /// 弹壳弹出效果路径
        /// </summary>
        public string ShellEjectPath { get; set; } = "";

        /// <summary>
        /// 射击震动强度
        /// </summary>
        public float CameraShakeIntensity { get; set; } = 0.1f;
        #endregion

        #region Special Properties
        /// <summary>
        /// 是否穿透敌人
        /// </summary>
        public bool CanPenetrate { get; set; } = false;

        /// <summary>
        /// 穿透伤害衰减
        /// </summary>
        public float PenetrationDamageFalloff { get; set; } = 0.5f;

        /// <summary>
        /// 最大穿透数
        /// </summary>
        public int MaxPenetrations { get; set; } = 1;

        /// <summary>
        /// 是否爆炸性弹药
        /// </summary>
        public bool IsExplosive { get; set; } = false;

        /// <summary>
        /// 爆炸半径
        /// </summary>
        public float ExplosionRadius { get; set; } = 0f;

        /// <summary>
        /// 爆炸伤害
        /// </summary>
        public float ExplosionDamage { get; set; } = 0f;

        /// <summary>
        /// 是否追踪弹药
        /// </summary>
        public bool IsHoming { get; set; } = false;

        /// <summary>
        /// 追踪强度
        /// </summary>
        public float HomingStrength { get; set; } = 0f;

        /// <summary>
        /// 特殊效果列表
        /// </summary>
        public List<WeaponEffect> Effects { get; set; } = new List<WeaponEffect>();
        #endregion

        #region Upgrade System
        /// <summary>
        /// 升级配置
        /// </summary>
        public WeaponUpgradeConfig UpgradeConfig { get; set; } = new WeaponUpgradeConfig();

        /// <summary>
        /// 获取指定等级的属性
        /// </summary>
        public WeaponStats GetStatsAtLevel(
            int damageLevel,
            int fireRateLevel,
            int magazineLevel,
            int reloadLevel,
            int accuracyLevel
        )
        {
            return new WeaponStats
            {
                Damage = CalculateUpgradedValue(BaseDamage, UpgradeConfig.DamageMultiplier, damageLevel),
                FireRate = CalculateUpgradedValue(FireRate, UpgradeConfig.FireRateMultiplier, fireRateLevel),
                MagazineSize = (int)CalculateUpgradedValue(
                    MagazineSize,
                    UpgradeConfig.MagazineMultiplier,
                    magazineLevel
                ),
                ReloadTime = CalculateUpgradedValue(ReloadTime, UpgradeConfig.ReloadMultiplier, reloadLevel, true),
                Accuracy = Math.Min(
                    1f,
                    CalculateUpgradedValue(BaseAccuracy, UpgradeConfig.AccuracyMultiplier, accuracyLevel)
                ),
            };
        }

        private float CalculateUpgradedValue(float baseValue, float multiplierPerLevel, int level, bool inverse = false)
        {
            if (inverse)
            {
                return baseValue * MathF.Pow(multiplierPerLevel, -level);
            }
            return baseValue * MathF.Pow(multiplierPerLevel, level);
        }
        #endregion

        #region Utility
        /// <summary>
        /// 获取射击间隔（秒）
        /// </summary>
        public float GetFireInterval()
        {
            return 1f / FireRate;
        }

        /// <summary>
        /// 获取DPS（每秒伤害）
        /// </summary>
        public float GetDPS()
        {
            return BaseDamage * FireRate;
        }

        /// <summary>
        /// 获取弹匣总伤害
        /// </summary>
        public float GetMagazineDamage()
        {
            return BaseDamage * MagazineSize;
        }

        /// <summary>
        /// 创建深拷贝
        /// </summary>
        public WeaponData Clone()
        {
            return new WeaponData
            {
                Id = this.Id,
                DisplayName = this.DisplayName,
                Description = this.Description,
                Type = this.Type,
                Rarity = this.Rarity,
                IconPath = this.IconPath,
                ModelPath = this.ModelPath,
                UnlockLevel = this.UnlockLevel,
                Price = this.Price,
                BaseDamage = this.BaseDamage,
                FireRate = this.FireRate,
                MagazineSize = this.MagazineSize,
                ReloadTime = this.ReloadTime,
                Range = this.Range,
                ProjectileSpeed = this.ProjectileSpeed,
                ProjectilePath = this.ProjectilePath,
                FireMode = this.FireMode,
                BurstCount = this.BurstCount,
                BurstInterval = this.BurstInterval,
                BaseAccuracy = this.BaseAccuracy,
                MovingAccuracyPenalty = this.MovingAccuracyPenalty,
                AccuracyDecay = this.AccuracyDecay,
                RecoilVertical = this.RecoilVertical,
                RecoilHorizontal = this.RecoilHorizontal,
                RecoilRecovery = this.RecoilRecovery,
                MuzzleClimb = this.MuzzleClimb,
                FireSoundPath = this.FireSoundPath,
                ReloadSoundPath = this.ReloadSoundPath,
                EmptySoundPath = this.EmptySoundPath,
                MuzzleFlashPath = this.MuzzleFlashPath,
                ShellEjectPath = this.ShellEjectPath,
                CameraShakeIntensity = this.CameraShakeIntensity,
                CanPenetrate = this.CanPenetrate,
                PenetrationDamageFalloff = this.PenetrationDamageFalloff,
                MaxPenetrations = this.MaxPenetrations,
                IsExplosive = this.IsExplosive,
                ExplosionRadius = this.ExplosionRadius,
                ExplosionDamage = this.ExplosionDamage,
                IsHoming = this.IsHoming,
                HomingStrength = this.HomingStrength,
                Effects = new List<WeaponEffect>(this.Effects),
                UpgradeConfig = this.UpgradeConfig.Clone(),
            };
        }
        #endregion
    }

    /// <summary>
    /// 武器类型枚举
    /// </summary>
    public enum WeaponType
    {
        Pistol, // 手枪
        Rifle, // 步枪
        SMG, // 冲锋枪
        Shotgun, // 霰弹枪
        Sniper, // 狙击枪
        LMG, // 轻机枪
        Rocket, // 火箭筒
        Melee, // 近战
        Special, // 特殊
    }

    /// <summary>
    /// 武器稀有度枚举
    /// </summary>
    public enum WeaponRarity
    {
        Common, // 普通（白色）
        Uncommon, // 优秀（绿色）
        Rare, // 稀有（蓝色）
        Epic, // 史诗（紫色）
        Legendary, // 传说（橙色）
        Mythic, // 神话（红色）
    }

    /// <summary>
    /// 射击模式枚举
    /// </summary>
    public enum FireMode
    {
        SemiAuto, // 半自动
        FullAuto, // 全自动
        Burst, // 连发
        Single, // 单发（栓动）
    }

    /// <summary>
    /// 武器效果
    /// </summary>
    public class WeaponEffect
    {
        public EffectType Type { get; set; }
        public float Value { get; set; }
        public float Duration { get; set; }
        public float Chance { get; set; }
    }

    /// <summary>
    /// 效果类型枚举
    /// </summary>
    public enum EffectType
    {
        Burn, // 燃烧
        Poison, // 中毒
        Slow, // 减速
        Stun, // 眩晕
        Freeze, // 冰冻
        Shock, // 电击
        LifeSteal, // 吸血
        ArmorPierce, // 破甲
        CriticalBoost, // 暴击提升
    }

    /// <summary>
    /// 武器升级配置
    /// </summary>
    public class WeaponUpgradeConfig
    {
        public int MaxDamageLevel { get; set; } = 5;
        public int MaxFireRateLevel { get; set; } = 5;
        public int MaxMagazineLevel { get; set; } = 5;
        public int MaxReloadLevel { get; set; } = 5;
        public int MaxAccuracyLevel { get; set; } = 5;

        public float DamageMultiplier { get; set; } = 1.15f; // 每级+15%
        public float FireRateMultiplier { get; set; } = 1.1f; // 每级+10%
        public float MagazineMultiplier { get; set; } = 1.2f; // 每级+20%
        public float ReloadMultiplier { get; set; } = 0.9f; // 每级-10%
        public float AccuracyMultiplier { get; set; } = 1.05f; // 每级+5%

        public int BaseUpgradeCost { get; set; } = 100;
        public float CostMultiplier { get; set; } = 1.5f;

        public WeaponUpgradeConfig Clone()
        {
            return new WeaponUpgradeConfig
            {
                MaxDamageLevel = this.MaxDamageLevel,
                MaxFireRateLevel = this.MaxFireRateLevel,
                MaxMagazineLevel = this.MaxMagazineLevel,
                MaxReloadLevel = this.MaxReloadLevel,
                MaxAccuracyLevel = this.MaxAccuracyLevel,
                DamageMultiplier = this.DamageMultiplier,
                FireRateMultiplier = this.FireRateMultiplier,
                MagazineMultiplier = this.MagazineMultiplier,
                ReloadMultiplier = this.ReloadMultiplier,
                AccuracyMultiplier = this.AccuracyMultiplier,
                BaseUpgradeCost = this.BaseUpgradeCost,
                CostMultiplier = this.CostMultiplier,
            };
        }
    }

    /// <summary>
    /// 武器运行时属性
    /// </summary>
    public struct WeaponStats
    {
        public float Damage;
        public float FireRate;
        public int MagazineSize;
        public float ReloadTime;
        public float Accuracy;
    }

    /// <summary>
    /// 武器数据库
    /// </summary>
    public static class WeaponDatabase
    {
        private static readonly Dictionary<string, WeaponData> _weapons = new Dictionary<string, WeaponData>();

        /// <summary>
        /// 注册武器
        /// </summary>
        public static void RegisterWeapon(WeaponData weapon)
        {
            _weapons[weapon.Id] = weapon;
        }

        /// <summary>
        /// 获取武器数据
        /// </summary>
        public static WeaponData? GetWeapon(string id)
        {
            _weapons.TryGetValue(id, out var weapon);
            return weapon?.Clone();
        }

        /// <summary>
        /// 检查武器是否存在
        /// </summary>
        public static bool HasWeapon(string id)
        {
            return _weapons.ContainsKey(id);
        }

        /// <summary>
        /// 获取所有武器
        /// </summary>
        public static IEnumerable<WeaponData> GetAllWeapons()
        {
            foreach (var weapon in _weapons.Values)
            {
                yield return weapon.Clone();
            }
        }

        /// <summary>
        /// 获取特定类型的武器
        /// </summary>
        public static IEnumerable<WeaponData> GetWeaponsByType(WeaponType type)
        {
            foreach (var weapon in _weapons.Values)
            {
                if (weapon.Type == type)
                {
                    yield return weapon.Clone();
                }
            }
        }

        /// <summary>
        /// 从JSON加载武器配置
        /// </summary>
        public static void LoadFromJson(string jsonPath)
        {
            // TODO: 实现JSON加载
            GD.Print($"Loading weapons from: {jsonPath}");
        }

        /// <summary>
        /// 清空数据库
        /// </summary>
        public static void Clear()
        {
            _weapons.Clear();
        }
    }
}
