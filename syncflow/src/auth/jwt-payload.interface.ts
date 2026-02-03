import { Role } from "src/enum/role.enum";

export interface JwtPayload {
  username: string;
  sub: number;
  role: Role;
  companyCode: string;
}
