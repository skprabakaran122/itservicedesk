import { useQuery } from "@tanstack/react-query";
import { FormField, FormItem, FormLabel, FormControl, FormMessage } from "@/components/ui/form";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { type Product } from "@shared/schema";
import { Control } from "react-hook-form";

interface ProductSelectProps {
  control: Control<any>;
  name: string;
  label?: string;
  placeholder?: string;
  required?: boolean;
}

export function ProductSelect({ 
  control, 
  name, 
  label = "Product (Optional)", 
  placeholder = "Select affected product",
  required = false 
}: ProductSelectProps) {
  const { data: products = [] } = useQuery<Product[]>({
    queryKey: ["/api/products"],
  });

  const activeProducts = products.filter(p => p.isActive === "true");

  return (
    <FormField
      control={control}
      name={name}
      render={({ field }) => (
        <FormItem>
          <FormLabel>{label}{required && " *"}</FormLabel>
          <Select onValueChange={field.onChange} defaultValue={field.value}>
            <FormControl>
              <SelectTrigger>
                <SelectValue placeholder={placeholder} />
              </SelectTrigger>
            </FormControl>
            <SelectContent>
              {activeProducts.length === 0 ? (
                <SelectItem value="" disabled>
                  No products available
                </SelectItem>
              ) : (
                activeProducts.map((product) => (
                  <SelectItem key={product.id} value={product.name}>
                    {product.name}
                  </SelectItem>
                ))
              )}
            </SelectContent>
          </Select>
          <FormMessage />
        </FormItem>
      )}
    />
  );
}