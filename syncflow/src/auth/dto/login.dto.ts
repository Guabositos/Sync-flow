import { IsString, MinLength } from 'class-validator';

export class LoginDto {
  @IsString({ message: 'Le nom d\'utilisateur doit être une chaîne de caractères' })
  @MinLength(3, { message: 'Le nom d\'utilisateur doit contenir au moins 3 caractères' })
  username: string;

  @IsString({ message: 'Le mot de passe doit être une chaîne de caractères' })
  @MinLength(6, { message: 'Le mot de passe doit contenir au moins 6 caractères' })
  password: string;

  @IsString({ message: 'Le code de la société doit être une chaîne de caractères' })
  @MinLength(3, { message: 'Le code de la société doit contenir au moins 3 caractères' })
    companyCode: string;
}