import { Module } from '@nestjs/common';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { JwtModule, JwtService } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { JwtStrategy } from './strategy/auth.strategy';
import { ConfigModule } from '../config/config.module';
import { ConfigService } from '../config/config.service';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from '../user/entities/user.entity';
import { Operation } from 'src/history/entities/operation.entity';
import type { StringValue } from "ms";


@Module({
  imports: [
    TypeOrmModule.forFeature([User, Operation]),
    ConfigModule,
    PassportModule.register({ defaultStrategy: 'jwt' }),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => {
        const jwtConfig = configService.getJwtConfig();
        return {
          secret: jwtConfig.jwtSecret,
          signOptions: { expiresIn: jwtConfig.jwtExpiration as StringValue },
        };
      },
    }),
  ],
  exports: [AuthService, JwtModule],
  providers: [AuthService, JwtStrategy],
  controllers: [AuthController]
})
export class AuthModule {}
