# A namespace in which are defined position-related classes.
module Roby::Pos
    # A (x, y, z) vector
    class Vector3D
        # The vector coordinates
	attr_accessor :x, :y, :z
        # Initializes a 3D vector
	def initialize(x = 0, y = 0, z = 0)
	    @x, @y, @z = x, y, z
	end

	def to_s # :nodoc:
            "#<Vector3D (x,y,z) = (%f,%f,%f)>" % [x,y,z] 
        end

        # The length of the vector
	def length; distance(0, 0, 0) end
        # Returns self + v
	def +(v); Vector3D.new(x + v.x, y + v.y, z + v.z) end
        # Returns self - v
	def -(v); Vector3D.new(x - v.x, y - v.y, z - v.z) end
        # Returns the product of this vector with the scalar +a+
	def *(a); Vector3D.new(x * a, y * a, z * a) end
        # Returns the division of this vector with the scalar +a+
	def /(a); Vector3D.new(x / a, y / a, z / a) end
        # Returns the opposite of this vector
	def -@; Vector3D.new(-x, -y, -z) end

        # Returns the [x, y, z] array
	def xyz; [x, y, z] end
        # True if +v+ is the same vector than +self+
	def ==(v)
	    v.kind_of?(Vector3D) &&
		v.x == x && v.y == y && v.z == z
	end

        # True if this vector is of zero length. If +tolerance+ is non-zero,
        # returns true if length <= tolerance.
	def null?(tolerance = 0)
	    length <= tolerance
	end

        # call-seq:
        #   v.distance2d w
        #   v.distance2d x, y
        #
        # Returns the euclidian distance in the (X,Y) plane, between this vector
        # and the given coordinates. In the first form, +w+ can be a vector in which
        # case the distance is computed between (self.x, self.y) and (w.x, w.y).
        # If +w+ is a scalar, it is taken as the X coordinate and y = 0.
        #
        # In the second form, both +x+ and +y+ must be scalars.
	def distance2d(x = 0, y = nil)
	    if !y && x.respond_to?(:x)
		x, y = x.x, x.y
	    else
		y ||= 0
	    end

	    Math.sqrt( (x - self.x) ** 2 + (y - self.y) ** 2 )
	end

        # call-seq:
        #   v.distance2d w
        #   v.distance2d x, y
        #   v.distance2d x, y, z
        #
        # Returns the euclidian distance in the (X,Y,Z) space, between this vector
        # and the given coordinates. In the first form, +w+ can be a vector in which
        # case the distance is computed between (self.x, self.y, self.z) and (w.x, w.y, w.z).
        # If +w+ is a scalar, it is taken as the X coordinate and y = z = 0.
        #
        # In the second form, both +x+ and +y+ must be scalars and z == 0.
	def distance(x = 0, y = nil, z = nil)
	    if !y && x.respond_to?(:x)
		x, y, z = x.x, x.y, x.z
	    else
		y ||= 0
		z ||= 0
	    end

	    Math.sqrt( (x - self.x) ** 2 + (y - self.y) ** 2 + (z - self.z) ** 2)
	end
    end

    # This class represents both a position and an orientation
    class Euler3D < Vector3D
        # The orientation angles
	attr_accessor :yaw, :pitch, :roll

        # Create an euler position object
	def initialize(x = 0, y = 0, z = 0, yaw = 0, pitch = 0, roll = 0)
	    super(x, y, z)
	    @yaw, @pitch, @roll = yaw, pitch, roll
	end

        # Returns [yaw, pitch, roll]
	def ypr
	    [yaw, pitch, roll]
	end

	def to_s # :nodoc:
            "#<Euler3D (x,y,z) = (%f,%f,%f); (y,p,r) = (%f,%f,%f)>" % [x,y,z,yaw,pitch,roll]
        end
    end
end
