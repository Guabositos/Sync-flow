import { Injectable, ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { JwtService } from '@nestjs/jwt';
import { Socket } from 'socket.io';
import { ConfigService } from '../../config/config.service';
import { request } from 'http';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  private readonly jwtSecret: string;

  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {
    super();
    this.jwtSecret = this.configService.getJwtConfig().jwtSecret;
  }

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const type = context.getType();

    if (type === 'http') {
      const request = context.switchToHttp().getRequest();
      
      // Check for token in query params and move to headers if present
      if (request.query?.token && !request.headers.authorization) {
        request.headers.authorization = `Bearer ${request.query.token}`;
      }
      
      return super.canActivate(context) as Promise<boolean>;
    }

    if (type === 'ws') {
      console.log("jwtauthguardactivated")
      // For WebSocket, custom JWT validation
      const client: Socket = context.switchToWs().getClient();
      
      // Check for token in auth object first, then in query params
      let token = client.handshake.auth.token;
      
      // If no token in auth, check query params
      if (!token && client.handshake.query?.token) {
        token = client.handshake.query.token;
      }
      
      if (!token) {
        throw new UnauthorizedException('No token provided in WebSocket handshake');
      }
      try {
        // Handle multiple tokens case
        if (Array.isArray(token)) {
          throw new UnauthorizedException('Multiple tokens provided in WebSocket handshake');
        }
        if( token.startsWith('Bearer ')) {
          token = token.slice(7, token.length).trim();
        }
        
        const payload = this.jwtService.verify(token, { secret: this.jwtSecret });
        console.log("token:", token);
        client.data.user = payload;
        console.log("ws payload:", payload);
        return true;
      } catch (err) {
        console.log("ws token error:", err);
        throw new UnauthorizedException('Invalid WebSocket token');
      }
    }

    throw new UnauthorizedException('Unknown context type');
  }
}
