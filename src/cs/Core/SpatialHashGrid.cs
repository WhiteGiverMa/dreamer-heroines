using Godot;
using System;
using System.Collections.Generic;

namespace StrikeForceLike.Core
{
    /// <summary>
    /// 空间哈希网格 - 用于优化2D空间查询和碰撞检测
    /// 将空间划分为网格，每个网格存储其中的对象，大幅减少需要检测的对象对
    /// </summary>
    public class SpatialHashGrid
    {
        #region Fields
        private readonly float _cellSize;
        private readonly Dictionary<long, List<Node2D>> _cells;
        private readonly Dictionary<Node2D, long> _objectCells;
        private readonly Dictionary<Node2D, Rect2> _objectBounds;
        #endregion

        #region Constructor
        /// <summary>
        /// 创建空间哈希网格
        /// </summary>
        /// <param name="cellSize">网格单元大小，应根据对象平均尺寸设置</param>
        public SpatialHashGrid(float cellSize)
        {
            _cellSize = cellSize;
            _cells = new Dictionary<long, List<Node2D>>();
            _objectCells = new Dictionary<Node2D, long>();
            _objectBounds = new Dictionary<Node2D, Rect2>();
        }
        #endregion

        #region Public Methods
        /// <summary>
        /// 将对象插入网格
        /// </summary>
        public void Insert(Node2D obj, Rect2 bounds)
        {
            if (obj == null) return;

            // 如果对象已存在，先移除
            if (_objectCells.ContainsKey(obj))
            {
                Remove(obj);
            }

            // 计算对象占据的网格单元
            int minX = (int)MathF.Floor(bounds.Position.X / _cellSize);
            int minY = (int)MathF.Floor(bounds.Position.Y / _cellSize);
            int maxX = (int)MathF.Floor(bounds.End.X / _cellSize);
            int maxY = (int)MathF.Floor(bounds.End.Y / _cellSize);

            // 存储对象边界
            _objectBounds[obj] = bounds;

            // 将对象添加到所有重叠的网格单元
            for (int x = minX; x <= maxX; x++)
            {
                for (int y = minY; y <= maxY; y++)
                {
                    long key = GetCellKey(x, y);
                    if (!_cells.TryGetValue(key, out var cell))
                    {
                        cell = new List<Node2D>();
                        _cells[key] = cell;
                    }
                    cell.Add(obj);
                    _objectCells[obj] = key;
                }
            }
        }

        /// <summary>
        /// 将对象插入网格（使用圆形边界）
        /// </summary>
        public void Insert(Node2D obj, Vector2 position, float radius)
        {
            Rect2 bounds = new Rect2(position - new Vector2(radius, radius), new Vector2(radius * 2, radius * 2));
            Insert(obj, bounds);
        }

        /// <summary>
        /// 从网格中移除对象
        /// </summary>
        public void Remove(Node2D obj)
        {
            if (obj == null || !_objectBounds.ContainsKey(obj)) return;

            Rect2 bounds = _objectBounds[obj];
            int minX = (int)MathF.Floor(bounds.Position.X / _cellSize);
            int minY = (int)MathF.Floor(bounds.Position.Y / _cellSize);
            int maxX = (int)MathF.Floor(bounds.End.X / _cellSize);
            int maxY = (int)MathF.Floor(bounds.End.Y / _cellSize);

            for (int x = minX; x <= maxX; x++)
            {
                for (int y = minY; y <= maxY; y++)
                {
                    long key = GetCellKey(x, y);
                    if (_cells.TryGetValue(key, out var cell))
                    {
                        cell.Remove(obj);
                        if (cell.Count == 0)
                        {
                            _cells.Remove(key);
                        }
                    }
                }
            }

            _objectCells.Remove(obj);
            _objectBounds.Remove(obj);
        }

        /// <summary>
        /// 更新对象位置（如果对象移动了）
        /// </summary>
        public void Update(Node2D obj, Rect2 newBounds)
        {
            if (obj == null) return;

            // 检查是否真的需要更新
            if (_objectBounds.TryGetValue(obj, out var oldBounds))
            {
                int oldMinX = (int)MathF.Floor(oldBounds.Position.X / _cellSize);
                int oldMinY = (int)MathF.Floor(oldBounds.Position.Y / _cellSize);
                int newMinX = (int)MathF.Floor(newBounds.Position.X / _cellSize);
                int newMinY = (int)MathF.Floor(newBounds.Position.Y / _cellSize);

                if (oldMinX == newMinX && oldMinY == newMinY)
                {
                    // 仍在同一个网格单元，只更新边界
                    _objectBounds[obj] = newBounds;
                    return;
                }
            }

            // 需要重新插入
            Remove(obj);
            Insert(obj, newBounds);
        }

        /// <summary>
        /// 更新对象位置（圆形边界）
        /// </summary>
        public void Update(Node2D obj, Vector2 position, float radius)
        {
            Rect2 bounds = new Rect2(position - new Vector2(radius, radius), new Vector2(radius * 2, radius * 2));
            Update(obj, bounds);
        }

        /// <summary>
        /// 查询与给定矩形相交的所有对象
        /// </summary>
        public List<Node2D> Query(Rect2 bounds)
        {
            HashSet<Node2D> result = new HashSet<Node2D>();

            int minX = (int)MathF.Floor(bounds.Position.X / _cellSize);
            int minY = (int)MathF.Floor(bounds.Position.Y / _cellSize);
            int maxX = (int)MathF.Floor(bounds.End.X / _cellSize);
            int maxY = (int)MathF.Floor(bounds.End.Y / _cellSize);

            for (int x = minX; x <= maxX; x++)
            {
                for (int y = minY; y <= maxY; y++)
                {
                    long key = GetCellKey(x, y);
                    if (_cells.TryGetValue(key, out var cell))
                    {
                        foreach (var obj in cell)
                        {
                            if (_objectBounds.TryGetValue(obj, out var objBounds))
                            {
                                if (bounds.Intersects(objBounds))
                                {
                                    result.Add(obj);
                                }
                            }
                        }
                    }
                }
            }

            return new List<Node2D>(result);
        }

        /// <summary>
        /// 查询与给定圆形相交的所有对象
        /// </summary>
        public List<Node2D> Query(Vector2 center, float radius)
        {
            Rect2 bounds = new Rect2(center - new Vector2(radius, radius), new Vector2(radius * 2, radius * 2));
            List<Node2D> candidates = Query(bounds);
            List<Node2D> result = new List<Node2D>();

            float radiusSquared = radius * radius;
            foreach (var obj in candidates)
            {
                if (obj is Node2D node2D)
                {
                    float distSq = center.DistanceSquaredTo(node2D.GlobalPosition);
                    if (distSq <= radiusSquared)
                    {
                        result.Add(obj);
                    }
                }
            }

            return result;
        }

        /// <summary>
        /// 查询与给定点附近的所有对象
        /// </summary>
        public List<Node2D> QueryNearby(Vector2 point, float radius)
        {
            return Query(point, radius);
        }

        /// <summary>
        /// 获取指定网格单元中的所有对象
        /// </summary>
        public List<Node2D> GetCell(int x, int y)
        {
            long key = GetCellKey(x, y);
            if (_cells.TryGetValue(key, out var cell))
            {
                return new List<Node2D>(cell);
            }
            return new List<Node2D>();
        }

        /// <summary>
        /// 获取对象当前所在的网格单元坐标
        /// </summary>
        public Vector2I GetObjectCell(Node2D obj)
        {
            if (_objectCells.TryGetValue(obj, out long key))
            {
                return DecodeCellKey(key);
            }
            return new Vector2I(int.MinValue, int.MinValue);
        }

        /// <summary>
        /// 清空整个网格
        /// </summary>
        public void Clear()
        {
            _cells.Clear();
            _objectCells.Clear();
            _objectBounds.Clear();
        }

        /// <summary>
        /// 获取网格中的对象数量
        /// </summary>
        public int Count => _objectBounds.Count;

        /// <summary>
        /// 获取网格单元数量
        /// </summary>
        public int CellCount => _cells.Count;
        #endregion

        #region Private Methods
        /// <summary>
        /// 将网格坐标编码为长整型键
        /// </summary>
        private static long GetCellKey(int x, int y)
        {
            // 使用位运算将两个int合并为一个long
            // 高32位存储x，低32位存储y
            return ((long)x << 32) | (uint)y;
        }

        /// <summary>
        /// 将长整型键解码为网格坐标
        /// </summary>
        private static Vector2I DecodeCellKey(long key)
        {
            int x = (int)(key >> 32);
            int y = (int)(key & 0xFFFFFFFF);
            return new Vector2I(x, y);
        }
        #endregion
    }

    /// <summary>
    /// 空间哈希网格管理器 - 用于管理多个网格层
    /// </summary>
    public class SpatialHashGridManager
    {
        private readonly Dictionary<string, SpatialHashGrid> _grids;

        public SpatialHashGridManager()
        {
            _grids = new Dictionary<string, SpatialHashGrid>();
        }

        /// <summary>
        /// 创建新的网格层
        /// </summary>
        public SpatialHashGrid CreateGrid(string name, float cellSize)
        {
            var grid = new SpatialHashGrid(cellSize);
            _grids[name] = grid;
            return grid;
        }

        /// <summary>
        /// 获取网格层
        /// </summary>
        public SpatialHashGrid? GetGrid(string name)
        {
            _grids.TryGetValue(name, out var grid);
            return grid;
        }

        /// <summary>
        /// 移除网格层
        /// </summary>
        public void RemoveGrid(string name)
        {
            _grids.Remove(name);
        }

        /// <summary>
        /// 清空所有网格
        /// </summary>
        public void ClearAll()
        {
            foreach (var grid in _grids.Values)
            {
                grid.Clear();
            }
        }
    }
}
