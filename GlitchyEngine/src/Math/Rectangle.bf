using Bon;
using System;

namespace GlitchyEngine.Math;

enum IntersectionMode
{
	Disjoint,
	Intersects,
	Contains
}

[BonTarget, CRepr]
struct Rectangle
{
	private float2 _topLeft;
	private float2 _size;

	public float2 TopLeft
	{
		get => _topLeft;
		set mut => _topLeft = value;
	}
	
	public float2 Size
	{
		get => _size;
		set mut => _size = value;
	}

	public float2 BottomRight
	{
		get => _topLeft + _size;
		set mut
		{
			_size = value - _topLeft;
			
			if (_size.X < 0)
			{
				_size.X = -_size.X;
				_topLeft.X = value.X;
			}

			if (_size.Y < 0)
			{
				_size.Y = -_size.Y;
				_topLeft.Y = value.Y;
			}
		}
	}
	
	public float Left
	{
		get => _topLeft.X;
		set mut => _topLeft.X = value;
	}

	public float Top
	{
		get => _topLeft.Y;
		set mut => _topLeft.Y = value;
	}

	public float Right
	{
		get => _topLeft.X + _size.X;
		set mut => _size.X = value - _topLeft.X;
	}
	
	public float Bottom
	{
		get => _topLeft.Y + _size.Y;
		set mut => _size.Y = value - _topLeft.Y;
	}

	public this(float2 topLeft, float2 size)
	{
		_topLeft = topLeft;
		_size = size;
	}

	public bool Contains(float2 point)
	{
		return all(_topLeft <= point) && all(BottomRight >= point);
	}
	
	public IntersectionMode Collision(Rectangle other)
	{
		if (any(other.TopLeft >= this.BottomRight) || any(other.BottomRight <= this.TopLeft))
		{
		    return .Disjoint;
		}

		if (all(other.TopLeft >= this.TopLeft) && all(other.BottomRight <= this.BottomRight))
		{
		    return .Contains;
		}

		return .Intersects;
	}

	public bool Intersects(Rectangle other)
	{
		return !(other.Left > Right
             || other.Top > Bottom
             || other.Right < Left
             || other.Bottom < Top
            );
	}
}