module Spree
  class PaymentMethodTransactionsReport < Spree::Report
    DEFAULT_SORTABLE_ATTRIBUTE = :payment_method_name
    HEADERS = { payment_method_name: :string, months_name: :string, payment_amount: :integer }
    SEARCH_ATTRIBUTES = { start_date: :payments_created_from, end_date: :payments_created_till }
    SORTABLE_ATTRIBUTES = []

    def self.no_pagination?
      true
    end

    def generate
      payments = SpreeReportify::ReportDb[:spree_payment_methods___payment_methods].
      join(:spree_payments___payments, payment_method_id: :id).
      where(payments__created_at: @start_date..@end_date). #filter by params
      select{[
        Sequel.as(payment_methods__name, :payment_method_name),
        Sequel.as(payments__amount, :payment_amount),
        Sequel.as(MONTHNAME(:payments__created_at), :month_name),
        Sequel.as(MONTH(:payments__created_at), :number),
        Sequel.as(YEAR(:payments__created_at), :year)
      ]}

      group_by_months = SpreeReportify::ReportDb[payments].
      group(:months_name, :payment_method_name).
      order(:year, :number).
      select{[
        number,
        payment_method_name,
        year,
        Sequel.as(concat(month_name, ' ', year), :months_name),
        Sequel.as(SUM(payment_amount), :payment_amount)
      ]}

      grouped_by_payment_method_name = group_by_months.all.group_by { |record| record[:payment_method_name] }
      data = []
      grouped_by_payment_method_name.each_pair do |name, collection|
        data << fill_missing_values({ payment_method_name: name, payment_amount: 0 }, collection)
      end
      @data = data.flatten
    end

    def group_by_payment_method_name
      @grouped_by_payment_method_name ||= @data.group_by { |record| record[:payment_method_name] }
    end

    def chart_data
      {
        months_name: group_by_payment_method_name.first.second.map { |record| record[:months_name] },
        collection: group_by_payment_method_name
      }
    end

    def chart_json
      {
        chart: true,
        charts: [
          {
            id: 'payment-methods',
            json: {
              chart: { type: 'column' },
              title: { text: 'Payment Methods' },
              xAxis: { categories: chart_data[:months_name] },
              yAxis: {
                title: { text: 'Count' }
              },
              tooltip: { valuePrefix: '#' },
              legend: {
                  layout: 'vertical',
                  align: 'right',
                  verticalAlign: 'middle',
                  borderWidth: 0
              },
              series: chart_data[:collection].map { |key, value| { name: key, data: value.map { |r| r[:payment_amount].to_f } } }
            }
          }
        ]
      }
    end

    def select_columns(dataset)
      dataset
    end
  end
end
