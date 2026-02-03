
/*
  responsable for loading and providing configuration settings throughout the application

  check .netenv file at the root of the project for configuration variables
  
  check the service for all possible imports 

  !!! dont use the get() unless for debugging otherwise create new function for the importssssss that are needed
*/
import { Global, Module } from '@nestjs/common';
import { ConfigModule as NestConfigModule } from '@nestjs/config';
import { ConfigService } from './config.service';
import { Config } from './config.interface';
import * as path from 'path';
@Global()
@Module({
  imports: [
    NestConfigModule.forRoot({
      isGlobal: true, 
      envFilePath: path.resolve(__dirname, '../../.env'), 
    }),
  ],
  providers: [ConfigService],
  exports: [ConfigService],
})
export class ConfigModule {}
