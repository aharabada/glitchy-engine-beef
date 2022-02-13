using System;
using GlitchyEngine.Math;
namespace Sandbox
{
	struct Line2D
	{
		public Vector2 Start;
		public Vector2 End;

		public this(Vector2 start, Vector2 end)
		{
			Start = start;
			End = end;
		}

		/// Returns true if the given point lies on the line.
		public bool OnLine(Vector2 point)
		{
			Vector2 startToPoint = point - Start;
			Vector2 startToEnd = End - Start;

			float cross = cross(startToPoint, startToEnd);

			if(!MathHelper.IsZero(cross))
				return false;

			if(Math.Abs(startToEnd.X) >= Math.Abs(startToEnd.Y))
			{
				return (startToEnd.X > 0.0f) ?
					(Start.X <= point.X && point.X <= End.X) :
					(End.X <= point.X && point.X <= Start.X);
			}
			else
			{
				return (startToEnd.Y > 0.0f) ?
					(Start.Y <= point.Y && point.Y <= End.Y) :
					(End.Y <= point.Y && point.Y <= Start.Y);
			}
		}

		[Inline]
		private float cross(Vector2 v, Vector2 w)
		{
			return v.X * w.Y - v.Y * w.X;
		}

		public enum LineIntersection
		{
			case Collinear(Line2D IntersectionLine);
			case CollinearNoIntersect;
			case Parallel;
			case Intersection(Vector2 Point);
			case None;
		}
		
		private Result<(float Start, float End)> IntervalIntersection(float startA, float endA, float startB, float endB)
		{
			if(startB > endA || startA > endB)
				return .Err;
			else
			{
				float start = Math.Max(startA, startB);
				float end = Math.Min(endA, endB);

				return .Ok((start, end));
			}
		}

		public LineIntersection Intersects(Line2D line)
		{
			Vector2 A = this.Start;
			Vector2 B = this.End;
			Vector2 C = line.Start;
			Vector2 D = line.End;

			float numR = ((A.Y-C.Y) * (D.X-C.X) - (A.X-C.X) * (D.Y-C.Y));
			float den = ((B.X-A.X) * (D.Y-C.Y)-(B.Y-A.Y) * (D.X-C.X));

			float r =  numR / den;
			float s = ((A.Y-C.Y) * (B.X-A.X) - (A.X-C.X) * (B.Y-A.Y)) / den;

			if((0 <= r && r <= 1) && (0 <= s && s <= 1))
			{
				Vector2 P = A + r * (B - A);

				return .Intersection(P);
			}
			else if(MathHelper.IsZero(den))
			{
				if(MathHelper.IsZero(numR))
				{
					Vector2 AtoB = B - A;
					Vector2 CtoD = D - C;

					float r_dot_r = Vector2.Dot(AtoB, AtoB);

					// t0 = (q − p) · r / (r · r)
					float t0 = Vector2.Dot((C - A), AtoB) / r_dot_r;

					// t1 = (q + s − p) · r / (r · r) = t0 + s · r / (r · r)
					float t1 = t0 + Vector2.Dot(CtoD, AtoB) / r_dot_r;

					// do interval intersection

					if(Vector2.Dot(CtoD, AtoB) < 0)
					{
						Swap!(t0, t1);
					}

					if(IntervalIntersection(t0, t1, 0, 1) case .Ok(let intersection))
					{
						return .Collinear(Line2D(A + intersection.Start * AtoB, A + intersection.End * AtoB));
					}
					else
					{
						return .CollinearNoIntersect;
					}
				}
				else
				{
					return .Parallel;
				}
			}

			return .None;
		}

		public static void TestIntersects()
		{

			{
				Line2D line = .(.(0, 0), .(4, 0));

				Line2D intersecting = .(.(2, 2), .(2, -2));

				var result = line.Intersects(intersecting);
				Vector2 intersection;
				Runtime.Assert(result case .Intersection(out intersection));
				Runtime.Assert(intersection == .(2, 0));
			}

			{
				Line2D line = .(.(0, -1), .(5, 2));

				Line2D intersecting = .(.(1, 3), .(4, -2));

				var result = line.Intersects(intersecting);
				Vector2 intersection;
				Runtime.Assert(result case .Intersection(out intersection));
				Runtime.Assert(intersection == .(2.5f, 0.5f));
			}

			{
				Line2D line = .(.(-1, 0), .(1, 0));

				Line2D collinear = .(.(2, 0), .( 4, 0));

				var result = line.Intersects(collinear);

				Runtime.Assert(result case .CollinearNoIntersect);
			}

			{
				Line2D line = .(.(-1, 0), .(2, 0));

				Line2D collinear = .(.(1, 0), .( 4, 0));

				var result = line.Intersects(collinear);
				
				Line2D intersection;
				Runtime.Assert(result case .Collinear(out intersection));
				
				Runtime.Assert(intersection.Start == .(1, 0));
				Runtime.Assert(intersection.End == .(2, 0));
			}

			{
				Line2D line = .(.(-1, 5), .(2, 5));

				Line2D collinear = .(.(4, 5), .(1, 5));

				var result = line.Intersects(collinear);
				
				Line2D intersection;
				Runtime.Assert(result case .Collinear(out intersection));

				Runtime.Assert(intersection.Start == .(1, 5));
				Runtime.Assert(intersection.End == .(2, 5));
			}
		}

		/*
		public bool Intersects(Line2D line)
		{
			float x1 = Start.X;
			float x2 = End.X;
			float x3 = line.Start.X;
			float x4 = line.End.X;

			float y1 = Start.Y;
			float y2 = End.Y;
			float y3 = line.Start.Y;
			float y4 = line.End.Y;

			float t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / ((x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4));

			float u = ((x1 - x3) * (y1 - y2) - (y1 - y3) * (x1 - x2)) / ((x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4));

			return (0.0f <= t && t <= 1.0f && 0.0f <= u && u <= 1.0f);
		}
		*/
	}
}