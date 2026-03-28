using System;
using Godot;

namespace DreamerHeroines.Systems
{
    public interface IGameplaySaveState
    {
        bool IsGameplayActive { get; }
        int ConsumePendingPlaytimeSeconds();
    }

    internal sealed class UnavailableGameplaySaveState : IGameplaySaveState
    {
        public static readonly UnavailableGameplaySaveState Instance = new UnavailableGameplaySaveState();

        private UnavailableGameplaySaveState() { }

        public bool IsGameplayActive => false;

        public int ConsumePendingPlaytimeSeconds() => 0;
    }

    internal sealed class NodeGameplaySaveStateAdapter : IGameplaySaveState
    {
        private const string IsGameplayActiveMethodName = "is_gameplay_active";
        private const string ConsumePendingPlaytimeMethodName = "consume_pending_playtime_seconds";

        private readonly Node _provider;

        public NodeGameplaySaveStateAdapter(Node provider)
        {
            _provider = provider;
        }

        public bool IsGameplayActive
        {
            get
            {
                if (!GodotObject.IsInstanceValid(_provider) || !_provider.HasMethod(IsGameplayActiveMethodName))
                {
                    return false;
                }

                return _provider.Call(IsGameplayActiveMethodName).AsBool();
            }
        }

        public int ConsumePendingPlaytimeSeconds()
        {
            if (!GodotObject.IsInstanceValid(_provider) || !_provider.HasMethod(ConsumePendingPlaytimeMethodName))
            {
                return 0;
            }

            Variant pendingPlaytime = _provider.Call(ConsumePendingPlaytimeMethodName);
            if (pendingPlaytime.VariantType != Variant.Type.Int)
            {
                return 0;
            }

            return pendingPlaytime.AsInt32();
        }
    }
}
