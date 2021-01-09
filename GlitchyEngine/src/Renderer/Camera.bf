using System;
using GlitchyEngine.Math;

namespace GlitchyEngine.Renderer
{
	public abstract class Camera
	{
		protected Matrix _view;
		protected Matrix _transform;
		protected Matrix _projection;
		protected Matrix _viewProjection;

		protected float _nearPlane;
		protected float _farPlane;

		protected Vector3 _position;
		protected Vector3 _rotation;

		/// If true the transform matrix is outdated and needs to be recalculated.
		protected bool _transformOutdated = true;
		
		/// If true the projection matrix is outdated and needs to be recalculated.
		protected bool _projectionOutdated = true;

		public Matrix Transform => _transform;

		public Matrix View => _view;

		public Matrix Projection => _projection;

		public Matrix ViewProjection => _viewProjection;

		public float NearPlane
		{
			get => _nearPlane;
			set
			{
				if(_nearPlane == value)
					return;
				
				_nearPlane = value;

				_projectionOutdated = true;
			}
		}

		public float FarPlane
		{
			get => _farPlane;
			set
			{
				if(_farPlane == value)
					return;
				
				_farPlane = value;

				_projectionOutdated = true;
			}
		}

		public Vector3 Position
		{
			get => _position;
			set
			{
				if(_position == value)
					return;

				_position = value;
				_transformOutdated = true;
			}
		}
		
		public Vector3 Rotation
		{
			get => _rotation;
			set
			{
				if(_rotation == value)
					return;

				_rotation = value;
				_transformOutdated = true;
			}
		}

		public void Update()
		{
			bool changed = false;

			if(_transformOutdated)
			{
				UpdateTransform();
				_transformOutdated = false;
				changed = true;
			}

			if(_projectionOutdated)
			{
				UpdateProjection();
				_projectionOutdated = false;
				changed = true;
			}

			if(changed)
				_viewProjection = _projection * _view;
		}

		protected abstract void UpdateTransform();
		protected abstract void UpdateProjection();
	}
}
