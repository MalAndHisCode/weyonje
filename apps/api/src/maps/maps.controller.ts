import {
  Body,
  Controller,
  Get,
  ParseFloatPipe,
  Post,
  Query,
  UseGuards,
} from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
import {
  IsLatitude,
  IsLongitude,
  IsString,
  MaxLength,
  MinLength,
  ValidateNested,
} from "class-validator";
import { Type } from "class-transformer";
import { AccessTokenGuard } from "../auth/access-token.guard";
import { MapsService } from "./maps.service";

class PointDto {
  @IsLatitude() latitude!: number;
  @IsLongitude() longitude!: number;
}
class RouteDto {
  @ValidateNested() @Type(() => PointDto) origin!: PointDto;
  @ValidateNested() @Type(() => PointDto) destination!: PointDto;
}
class SearchDto {
  @IsString() @MinLength(2) @MaxLength(200) text!: string;
}

@ApiTags("maps")
@ApiBearerAuth()
@UseGuards(AccessTokenGuard)
@Controller("v1/maps")
export class MapsController {
  constructor(private readonly maps: MapsService) {}
  @Post("search") search(@Body() body: SearchDto) {
    return this.maps.search(body.text);
  }
  @Get("reverse") reverse(
    @Query("latitude", ParseFloatPipe) latitude: number,
    @Query("longitude", ParseFloatPipe) longitude: number,
  ) {
    return this.maps.reverse(latitude, longitude);
  }
  @Post("route") route(@Body() body: RouteDto) {
    return this.maps.route(body.origin, body.destination);
  }
}
