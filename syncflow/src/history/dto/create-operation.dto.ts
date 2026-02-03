import { IsEnum, IsNotEmpty } from "class-validator";
import { Company } from "src/company/entities/company.entity";
import { OperationType } from "src/enum/operation-type";
import { Target } from "src/enum/target.enum";
import { User } from "src/user/entities/user.entity";

export class CreateOperationDto {
    @IsEnum(OperationType)
    @IsNotEmpty()
    type: OperationType;
    @IsNotEmpty()
    date: Date;
    @IsNotEmpty()
    description: string;
    @IsEnum(Target)
    @IsNotEmpty()
    targettype: Target;
    @IsNotEmpty()
    target: number;
    @IsNotEmpty()
    performedBy: User; // Assuming this is the ID of the user performing the operation
    @IsNotEmpty()
    company : Company;
}
