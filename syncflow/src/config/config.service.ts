import { Injectable } from '@nestjs/common';
import { ConfigService as NestConfigService } from '@nestjs/config';
import { Config, DatabaseConfig } from './config.interface';

@Injectable()
export class ConfigService {
  constructor(private configService: NestConfigService) {}

  get<T>(key: string): T {
    const val = this.configService.get<string>(key);
    if(!val) {
        throw new Error(`Key ${key} not found in the configuration`);
    }
    return val as T;
  }

  getDatabaseConfig(): DatabaseConfig {
    return {
      host: this.configService.get<string>('DATABASE_HOST') || 'localhost',
      port: this.configService.get<number>('DATABASE_PORT') || 3306,
      username: this.configService.get<string>('DATABASE_USERNAME') || 'newuser',
      password: this.configService.get<string>('DATABASE_PASSWORD') || 'password',
      database: this.configService.get<string>('DATABASE_NAME') || 'syncflow',
    };
  }

  getJwtConfig() {
    return {
      jwtSecret: this.configService.get<string>('JWT_SECRET') || 'yoursecretkey',
      jwtExpiration: this.configService.get<string>('JWT_EXPIRATION') || '1h',
      jwtRefreshSecret: this.configService.get<string>('JWT_REFRESH_SECRET') || 'yourrefreshsecretkey',
      jwtRefreshExpiration: this.configService.get<string>('JWT_REFRESH_EXPIRATION') || '7d',
    };
  }
}


