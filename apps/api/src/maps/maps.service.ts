import {
  Inject,
  Injectable,
  ServiceUnavailableException,
} from "@nestjs/common";
import { ConfigType } from "@nestjs/config";
import { ApiErrorCode } from "@weyonje/contracts";
import { mapsConfig } from "../config/maps.config";

@Injectable()
export class MapsService {
  constructor(
    @Inject(mapsConfig.KEY)
    private readonly config: ConfigType<typeof mapsConfig>,
  ) {}

  async search(text: string) {
    const response = await this.request(
      "https://places.googleapis.com/v1/places:searchText",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Goog-Api-Key": this.key(),
          "X-Goog-FieldMask":
            "places.id,places.displayName,places.formattedAddress,places.location",
        },
        body: JSON.stringify({ textQuery: text, regionCode: "UG" }),
      },
    );
    const body = (await response.json()) as {
      places?: Array<{
        id: string;
        displayName?: { text?: string };
        formattedAddress?: string;
        location?: { latitude?: number; longitude?: number };
      }>;
    };
    return (body.places ?? [])
      .filter(
        (place) =>
          typeof place.location?.latitude === "number" &&
          typeof place.location.longitude === "number",
      )
      .map((place) => ({
        id: place.id,
        name: place.displayName?.text ?? place.formattedAddress ?? "Location",
        address: place.formattedAddress ?? "",
        latitude: place.location!.latitude!,
        longitude: place.location!.longitude!,
      }));
  }

  async reverse(latitude: number, longitude: number) {
    const url = new URL("https://maps.googleapis.com/maps/api/geocode/json");
    url.searchParams.set("latlng", `${latitude},${longitude}`);
    url.searchParams.set("key", this.key());
    const body = (await (await this.request(url.toString())).json()) as {
      results?: Array<{ formatted_address?: string; place_id?: string }>;
    };
    const first = body.results?.[0];
    return {
      address: first?.formatted_address ?? null,
      placeId: first?.place_id ?? null,
      latitude,
      longitude,
    };
  }

  async route(
    origin: { latitude: number; longitude: number },
    destination: { latitude: number; longitude: number },
  ) {
    const response = await this.request(
      "https://routes.googleapis.com/directions/v2:computeRoutes",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Goog-Api-Key": this.key(),
          "X-Goog-FieldMask":
            "routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline",
        },
        body: JSON.stringify({
          origin: { location: { latLng: origin } },
          destination: { location: { latLng: destination } },
          travelMode: "DRIVE",
          routingPreference: "TRAFFIC_AWARE",
        }),
      },
    );
    const body = (await response.json()) as {
      routes?: Array<{
        distanceMeters?: number;
        duration?: string;
        polyline?: { encodedPolyline?: string };
      }>;
    };
    return body.routes?.[0] ?? null;
  }

  private key(): string {
    if (!this.config.serverApiKey)
      throw this.unavailable("Google Maps server services are not configured.");
    return this.config.serverApiKey;
  }

  private async request(url: string, init?: RequestInit): Promise<Response> {
    const controller = new AbortController();
    const timer = setTimeout(
      () => controller.abort(),
      this.config.timeoutMilliseconds,
    );
    try {
      const response = await fetch(url, { ...init, signal: controller.signal });
      if (!response.ok)
        throw this.unavailable(
          response.status === 429
            ? "Google Maps quota is unavailable. Use coordinate or address text instead."
            : "Google Maps could not complete this request.",
        );
      return response;
    } catch (error) {
      if (error instanceof ServiceUnavailableException) throw error;
      throw this.unavailable("Google Maps timed out or is unavailable.");
    } finally {
      clearTimeout(timer);
    }
  }

  private unavailable(message: string) {
    return new ServiceUnavailableException({
      code: ApiErrorCode.dependencyUnavailable,
      message,
    });
  }
}
