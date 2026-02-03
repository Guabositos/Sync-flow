import { Controller, Delete, Param, UseGuards } from '@nestjs/common';
import { Post, Body } from '@nestjs/common';
import { AuthService } from './auth.service';
import { Roles } from './decorator/roles.decorator';
import { ConnectedUser } from './decorator/user.decorator';
import { CreateUserDto } from './dto/create-user.dto';
import { User } from '../user/entities/user.entity';
import { JwtPayload } from './jwt-payload.interface';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { LoginDto } from './dto/login.dto';
import { Role } from 'src/enum/role.enum';
import { RolesGuard } from './role-guard';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('login')
  async login(@Body() loginDto: LoginDto): Promise<{ access_token: string, refresh_token: string }> {
    return this.authService.login(loginDto);
  }
  
  @UseGuards(JwtAuthGuard, RolesGuard) 
  @Roles([Role.MANAGER]) 
  @Post('create-user')
  async createUser(
    @Body() createUserDto: CreateUserDto,
    @ConnectedUser() manager: JwtPayload
  ) {
    return this.authService.createUser(createUserDto, manager);
  }
  @Post('logout')
  @UseGuards(JwtAuthGuard)
  async logout(@ConnectedUser() user: JwtPayload) {
    return this.authService.logout(user);
  }
  @Post("refresh")
  async refresh(@Body() body: { refreshToken: string }): Promise<{ access_token: string, refresh_token: string }> {
    console.log('Refresh token request received:', body.refreshToken);
    return this.authService.refresh(body.refreshToken);
  }

  @Delete('delete-user/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles([Role.MANAGER])
  async deleteUser(
    @ConnectedUser() manager: JwtPayload,
    @Param('id') id: number
  ) {
    return this.authService.deleteUser(id, manager);
  }

}
