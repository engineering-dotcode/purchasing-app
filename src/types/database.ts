
export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

export type Database = {
  
  "graphql_public": {
          Tables: {
            [_ in never]: never
          }
          Views: {
            [_ in never]: never
          }
          Functions: {
            "graphql":
{ Args: { "extensions"?: Json,"operationName"?: string,"query"?: string,"variables"?: Json }; Returns: Json
                           }
          }
          Enums: {
            [_ in never]: never
          }
          CompositeTypes: {
            [_ in never]: never
          }
        },"public": {
          Tables: {
            "organizations": {
                  Row: {
                    "created_at": string,"deleted_at": string | null,"id": string,"name": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"deleted_at"?: string | null,"id"?: string,"name": string,"updated_at"?: string
                  }
                  Update: {
                    "created_at"?: string,"deleted_at"?: string | null,"id"?: string,"name"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    
                  ]
                },"products": {
                  Row: {
                    "created_at": string,"created_by": string,"deleted_at": string | null,"id": string,"name": string,"organization_id": string,"sku": string,"unit_price": number,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"created_by": string,"deleted_at"?: string | null,"id"?: string,"name": string,"organization_id": string,"sku": string,"unit_price"?: number,"updated_at"?: string
                  }
                  Update: {
                    "created_at"?: string,"created_by"?: string,"deleted_at"?: string | null,"id"?: string,"name"?: string,"organization_id"?: string,"sku"?: string,"unit_price"?: number,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "products_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    }
                  ]
                },"purchase_order_counters": {
                  Row: {
                    "last_number": number,"organization_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "last_number": number,"organization_id": string
                  }
                  Update: {
                    "last_number"?: number,"organization_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "purchase_order_counters_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: true
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    }
                  ]
                },"purchase_order_emails": {
                  Row: {
                    "attempts": number,"created_at": string,"created_by": string,"deleted_at": string | null,"id": string,"last_error": string | null,"organization_id": string,"purchase_order_id": string,"sent_at": string | null,"to_email": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "attempts"?: number,"created_at"?: string,"created_by": string,"deleted_at"?: string | null,"id"?: string,"last_error"?: string | null,"organization_id": string,"purchase_order_id": string,"sent_at"?: string | null,"to_email": string,"updated_at"?: string
                  }
                  Update: {
                    "attempts"?: number,"created_at"?: string,"created_by"?: string,"deleted_at"?: string | null,"id"?: string,"last_error"?: string | null,"organization_id"?: string,"purchase_order_id"?: string,"sent_at"?: string | null,"to_email"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "purchase_order_emails_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "purchase_order_emails_organization_id_purchase_order_id_fkey"
      columns: ["organization_id","purchase_order_id"]
isOneToOne: false
      referencedRelation: "purchase_orders"
      referencedColumns: ["organization_id","id"]
    }
                  ]
                },"purchase_order_lines": {
                  Row: {
                    "id": string,"product_id": string,"purchase_order_id": string,"quantity": number,"received_quantity": number,"unit_price": number
                  }
                  ComputedFields: never
                  Insert: {
                    "id"?: string,"product_id": string,"purchase_order_id": string,"quantity": number,"received_quantity"?: number,"unit_price": number
                  }
                  Update: {
                    "id"?: string,"product_id"?: string,"purchase_order_id"?: string,"quantity"?: number,"received_quantity"?: number,"unit_price"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "purchase_order_lines_product_id_fkey"
      columns: ["product_id"]
isOneToOne: false
      referencedRelation: "products"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "purchase_order_lines_purchase_order_id_fkey"
      columns: ["purchase_order_id"]
isOneToOne: false
      referencedRelation: "purchase_orders"
      referencedColumns: ["id"]
    }
                  ]
                },"purchase_orders": {
                  Row: {
                    "created_at": string,"created_by": string,"deleted_at": string | null,"expected_at": string | null,"id": string,"notes": string | null,"order_number": string,"organization_id": string,"received_at": string | null,"status": Database["public"]['Enums']["purchase_order_status"],"total_amount": number,"updated_at": string,"vendor_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"created_by": string,"deleted_at"?: string | null,"expected_at"?: string | null,"id"?: string,"notes"?: string | null,"order_number": string,"organization_id": string,"received_at"?: string | null,"status"?: Database["public"]['Enums']["purchase_order_status"],"total_amount"?: number,"updated_at"?: string,"vendor_id": string
                  }
                  Update: {
                    "created_at"?: string,"created_by"?: string,"deleted_at"?: string | null,"expected_at"?: string | null,"id"?: string,"notes"?: string | null,"order_number"?: string,"organization_id"?: string,"received_at"?: string | null,"status"?: Database["public"]['Enums']["purchase_order_status"],"total_amount"?: number,"updated_at"?: string,"vendor_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "purchase_orders_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "purchase_orders_vendor_id_fkey"
      columns: ["vendor_id"]
isOneToOne: false
      referencedRelation: "vendors"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "purchase_orders_vendor_same_org_fk"
      columns: ["organization_id","vendor_id"]
isOneToOne: false
      referencedRelation: "vendors"
      referencedColumns: ["organization_id","id"]
    }
                  ]
                },"vendors": {
                  Row: {
                    "created_at": string,"created_by": string,"deleted_at": string | null,"email": string | null,"id": string,"name": string,"organization_id": string,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"created_by": string,"deleted_at"?: string | null,"email"?: string | null,"id"?: string,"name": string,"organization_id": string,"updated_at"?: string
                  }
                  Update: {
                    "created_at"?: string,"created_by"?: string,"deleted_at"?: string | null,"email"?: string | null,"id"?: string,"name"?: string,"organization_id"?: string,"updated_at"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "vendors_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    }
                  ]
                }
          }
          Views: {
            [_ in never]: never
          }
          Functions: {
            "archive_purchase_order":
{ Args: { "p_order_id": string }; Returns: undefined
                           },
"create_purchase_order":
{ Args: { "p_expected_at": string,"p_lines": Json,"p_notes": string,"p_vendor_id": string }; Returns: {
              "created_at": string,
"created_by": string,
"deleted_at": string | null,
"expected_at": string | null,
"id": string,
"notes": string | null,
"order_number": string,
"organization_id": string,
"received_at": string | null,
"status": Database["public"]['Enums']["purchase_order_status"],
"total_amount": number,
"updated_at": string,
"vendor_id": string
            }
                          SetofOptions: {
        from: "*"
        to: "purchase_orders"
        isOneToOne: true
        isSetofReturn: false
      } },
"current_org_id":
{ Args: Record<PropertyKey, never>; Returns: string
                           },
"record_purchase_order_email_attempt":
{ Args: { "p_email_id": string,"p_error": string }; Returns: {
              "attempts": number,
"created_at": string,
"created_by": string,
"deleted_at": string | null,
"id": string,
"last_error": string | null,
"organization_id": string,
"purchase_order_id": string,
"sent_at": string | null,
"to_email": string,
"updated_at": string
            }
                          SetofOptions: {
        from: "*"
        to: "purchase_order_emails"
        isOneToOne: true
        isSetofReturn: false
      } },
"submit_purchase_order":
{ Args: { "p_order_id": string }; Returns: {
              "attempts": number,
"created_at": string,
"created_by": string,
"deleted_at": string | null,
"id": string,
"last_error": string | null,
"organization_id": string,
"purchase_order_id": string,
"sent_at": string | null,
"to_email": string,
"updated_at": string
            }
                          SetofOptions: {
        from: "*"
        to: "purchase_order_emails"
        isOneToOne: true
        isSetofReturn: false
      } },
"transition_purchase_order":
{ Args: { "p_next": Database["public"]['Enums']["purchase_order_status"],"p_order_id": string }; Returns: {
              "created_at": string,
"created_by": string,
"deleted_at": string | null,
"expected_at": string | null,
"id": string,
"notes": string | null,
"order_number": string,
"organization_id": string,
"received_at": string | null,
"status": Database["public"]['Enums']["purchase_order_status"],
"total_amount": number,
"updated_at": string,
"vendor_id": string
            }
                          SetofOptions: {
        from: "*"
        to: "purchase_orders"
        isOneToOne: true
        isSetofReturn: false
      } }
          }
          Enums: {
            "purchase_order_status": "DRAFT"|"PENDING_APPROVAL"|"SUBMITTED"|"CONFIRMED"|"PARTIALLY_RECEIVED"|"RECEIVED"|"CANCELLED"|"REJECTED"
          }
          CompositeTypes: {
            [_ in never]: never
          }
        }
}

type DatabaseWithoutInternals = Omit<Database, '__InternalSupabase'>

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
  ? (DefaultSchema["Tables"] & DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
      Row: infer R
    }
    ? R
    : never
  : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
  ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Insert: infer I
    }
    ? I
    : never
  : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
  ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Update: infer U
    }
    ? U
    : never
  : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never
> = DefaultSchemaEnumNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
  ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
  : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never
> = PublicCompositeTypeNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
  ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
  : never

export const Constants = {
  "graphql_public": {
          Enums: {
            
          }
        },"public": {
          Enums: {
            "purchase_order_status": ["DRAFT", "PENDING_APPROVAL", "SUBMITTED", "CONFIRMED", "PARTIALLY_RECEIVED", "RECEIVED", "CANCELLED", "REJECTED"]
          }
        }
} as const
