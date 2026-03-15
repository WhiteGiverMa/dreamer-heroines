using Godot;
using System;
using System.Collections.Generic;

namespace StrikeForceLike.Core
{
    /// <summary>
    /// 对象池接口，定义池化对象的基本行为
    /// </summary>
    public interface IPoolable
    {
        /// <summary>
        /// 当对象从池中取出时调用
        /// </summary>
        void OnSpawn();

        /// <summary>
        /// 当对象返回池中时调用
        /// </summary>
        void OnDespawn();

        /// <summary>
        /// 对象是否正在使用中
        /// </summary>
        bool IsActive { get; set; }
    }

    /// <summary>
    /// 通用对象池 - 用于重用对象以减少GC压力
    /// </summary>
    /// <typeparam name="T">池化对象的类型</typeparam>
    public class ObjectPool<T> where T : class, IPoolable, new()
    {
        #region Fields
        private readonly Queue<T> _pool;
        private readonly int _maxSize;
        private readonly int _initialSize;
        private int _activeCount;
        private int _totalCreated;
        #endregion

        #region Properties
        /// <summary>
        /// 池中可用对象数量
        /// </summary>
        public int AvailableCount => _pool.Count;

        /// <summary>
        /// 活跃对象数量
        /// </summary>
        public int ActiveCount => _activeCount;

        /// <summary>
        /// 池的最大容量
        /// </summary>
        public int MaxSize => _maxSize;

        /// <summary>
        /// 总共创建的对象数量
        /// </summary>
        public int TotalCreated => _totalCreated;
        #endregion

        #region Constructor
        /// <summary>
        /// 创建对象池
        /// </summary>
        /// <param name="initialSize">初始对象数量</param>
        /// <param name="maxSize">最大容量（0表示无限制）</param>
        public ObjectPool(int initialSize = 10, int maxSize = 100)
        {
            _initialSize = initialSize;
            _maxSize = maxSize;
            _pool = new Queue<T>(initialSize);
            _activeCount = 0;
            _totalCreated = 0;

            // 预创建初始对象
            for (int i = 0; i < initialSize; i++)
            {
                T obj = CreateNew();
                _pool.Enqueue(obj);
            }
        }
        #endregion

        #region Public Methods
        /// <summary>
        /// 从池中获取对象
        /// </summary>
        public T Get()
        {
            T obj;

            if (_pool.Count > 0)
            {
                obj = _pool.Dequeue();
            }
            else if (_maxSize == 0 || _totalCreated < _maxSize)
            {
                obj = CreateNew();
            }
            else
            {
                // 池已满，返回null或创建新对象（根据需求）
                GD.PushWarning($"ObjectPool<{typeof(T).Name}> has reached max size ({_maxSize})");
                obj = CreateNew();
            }

            obj.IsActive = true;
            obj.OnSpawn();
            _activeCount++;

            return obj;
        }

        /// <summary>
        /// 将对象返回池中
        /// </summary>
        public void Return(T obj)
        {
            if (obj == null) return;

            if (!obj.IsActive)
            {
                GD.PushWarning($"Attempting to return inactive object to pool: {typeof(T).Name}");
                return;
            }

            obj.OnDespawn();
            obj.IsActive = false;
            _activeCount--;

            if (_maxSize == 0 || _pool.Count < _maxSize)
            {
                _pool.Enqueue(obj);
            }
            else
            {
                // 池已满，对象将被GC回收
                GD.PushWarning($"ObjectPool<{typeof(T).Name}> is full, discarding returned object");
            }
        }

        /// <summary>
        /// 清空池中的所有对象
        /// </summary>
        public void Clear()
        {
            _pool.Clear();
            _activeCount = 0;
            _totalCreated = 0;
        }

        /// <summary>
        /// 预热池，创建指定数量的对象
        /// </summary>
        public void WarmUp(int count)
        {
            int toCreate = Math.Min(count, _maxSize == 0 ? count : _maxSize - _totalCreated);
            for (int i = 0; i < toCreate; i++)
            {
                if (_pool.Count < count)
                {
                    T obj = CreateNew();
                    _pool.Enqueue(obj);
                }
            }
        }

        /// <summary>
        /// 收缩池到指定大小
        /// </summary>
        public void Shrink(int targetSize)
        {
            while (_pool.Count > targetSize)
            {
                _pool.Dequeue();
                _totalCreated--;
            }
        }
        #endregion

        #region Private Methods
        private T CreateNew()
        {
            _totalCreated++;
            return new T();
        }
        #endregion
    }

    /// <summary>
    /// Godot节点对象池 - 专门用于管理Godot节点
    /// </summary>
    public class NodePool<T> where T : Node, IPoolable, new()
    {
        #region Fields
        private readonly Queue<T> _pool;
        private readonly int _maxSize;
        private readonly Node _parent;
        private int _activeCount;
        private int _totalCreated;
        private PackedScene? _scene;
        #endregion

        #region Properties
        public int AvailableCount => _pool.Count;
        public int ActiveCount => _activeCount;
        public int MaxSize => _maxSize;
        public int TotalCreated => _totalCreated;
        #endregion

        #region Constructor
        /// <summary>
        /// 创建节点对象池
        /// </summary>
        /// <param name="parent">节点父对象</param>
        /// <param name="initialSize">初始对象数量</param>
        /// <param name="maxSize">最大容量</param>
        public NodePool(Node parent, int initialSize = 10, int maxSize = 100)
        {
            _parent = parent;
            _maxSize = maxSize;
            _pool = new Queue<T>(initialSize);
            _activeCount = 0;
            _totalCreated = 0;

            // 尝试加载场景
            string scenePath = $"res://scenes/pools/{typeof(T).Name}.tscn";
            if (ResourceLoader.Exists(scenePath))
            {
                _scene = GD.Load<PackedScene>(scenePath);
            }

            // 预创建初始对象
            for (int i = 0; i < initialSize; i++)
            {
                T obj = CreateNew();
                obj.ProcessMode = ProcessModeEnum.Disabled;
                obj.Hide();
                _pool.Enqueue(obj);
            }
        }

        /// <summary>
        /// 使用场景创建节点池
        /// </summary>
        public NodePool(Node parent, PackedScene scene, int initialSize = 10, int maxSize = 100)
        {
            _parent = parent;
            _maxSize = maxSize;
            _scene = scene;
            _pool = new Queue<T>(initialSize);
            _activeCount = 0;
            _totalCreated = 0;

            for (int i = 0; i < initialSize; i++)
            {
                T obj = CreateNew();
                obj.ProcessMode = ProcessModeEnum.Disabled;
                obj.Hide();
                _pool.Enqueue(obj);
            }
        }
        #endregion

        #region Public Methods
        /// <summary>
        /// 从池中获取节点
        /// </summary>
        public T Get()
        {
            T obj;

            if (_pool.Count > 0)
            {
                obj = _pool.Dequeue();
            }
            else if (_maxSize == 0 || _totalCreated < _maxSize)
            {
                obj = CreateNew();
            }
            else
            {
                GD.PushWarning($"NodePool<{typeof(T).Name}> has reached max size ({_maxSize})");
                obj = CreateNew();
            }

            obj.ProcessMode = ProcessModeEnum.Inherit;
            obj.Show();
            obj.IsActive = true;
            obj.OnSpawn();
            _activeCount++;

            return obj;
        }

        /// <summary>
        /// 将节点返回池中
        /// </summary>
        public void Return(T obj)
        {
            if (obj == null) return;

            if (!obj.IsActive)
            {
                GD.PushWarning($"Attempting to return inactive node to pool: {typeof(T).Name}");
                return;
            }

            obj.OnDespawn();
            obj.IsActive = false;
            obj.ProcessMode = ProcessModeEnum.Disabled;
            obj.Hide();

            // 重置变换
            if (obj is Node2D node2D)
            {
                node2D.Position = Vector2.Zero;
                node2D.Rotation = 0f;
                node2D.Scale = Vector2.One;
            }
            else if (obj is Node3D node3D)
            {
                node3D.Position = Vector3.Zero;
                node3D.Rotation = Vector3.Zero;
                node3D.Scale = Vector3.One;
            }

            _activeCount--;

            if (_maxSize == 0 || _pool.Count < _maxSize)
            {
                _pool.Enqueue(obj);
            }
            else
            {
                obj.QueueFree();
                _totalCreated--;
            }
        }

        /// <summary>
        /// 清空池中的所有节点
        /// </summary>
        public void Clear()
        {
            while (_pool.Count > 0)
            {
                T obj = _pool.Dequeue();
                obj.QueueFree();
            }
            _activeCount = 0;
            _totalCreated = 0;
        }

        /// <summary>
        /// 预热池
        /// </summary>
        public void WarmUp(int count)
        {
            int toCreate = Math.Min(count, _maxSize == 0 ? count : _maxSize - _totalCreated);
            for (int i = 0; i < toCreate; i++)
            {
                if (_pool.Count < count)
                {
                    T obj = CreateNew();
                    obj.ProcessMode = ProcessModeEnum.Disabled;
                    obj.Hide();
                    _pool.Enqueue(obj);
                }
            }
        }
        #endregion

        #region Private Methods
        private T CreateNew()
        {
            _totalCreated++;

            if (_scene != null)
            {
                T? instance = _scene.Instantiate<T>();
                if (instance == null)
                {
                    throw new InvalidOperationException($"Failed to instantiate scene for {typeof(T).Name}");
                }
                _parent.AddChild(instance);
                return instance;
            }
            else
            {
                T obj = new T();
                _parent.AddChild(obj);
                return obj;
            }
        }
        #endregion
    }

    /// <summary>
    /// 对象池管理器 - 管理多个对象池
    /// </summary>
    public class ObjectPoolManager
    {
        private static ObjectPoolManager? _instance;
        public static ObjectPoolManager Instance => _instance ??= new ObjectPoolManager();

        private readonly Dictionary<Type, object> _pools;

        private ObjectPoolManager()
        {
            _pools = new Dictionary<Type, object>();
        }

        /// <summary>
        /// 注册对象池
        /// </summary>
        public void RegisterPool<T>(ObjectPool<T> pool) where T : class, IPoolable, new()
        {
            _pools[typeof(T)] = pool;
        }

        /// <summary>
        /// 获取对象池
        /// </summary>
        public ObjectPool<T>? GetPool<T>() where T : class, IPoolable, new()
        {
            if (_pools.TryGetValue(typeof(T), out var pool))
            {
                return pool as ObjectPool<T>;
            }
            return null;
        }

        /// <summary>
        /// 获取或创建对象池
        /// </summary>
        public ObjectPool<T> GetOrCreatePool<T>(int initialSize = 10, int maxSize = 100) where T : class, IPoolable, new()
        {
            var pool = GetPool<T>();
            if (pool == null)
            {
                pool = new ObjectPool<T>(initialSize, maxSize);
                RegisterPool(pool);
            }
            return pool;
        }

        /// <summary>
        /// 清空所有对象池
        /// </summary>
        public void ClearAllPools()
        {
            foreach (var pool in _pools.Values)
            {
                if (pool is System.IDisposable disposable)
                {
                    disposable.Dispose();
                }
            }
            _pools.Clear();
        }
    }
}
