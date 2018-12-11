require "spec_helper"

describe Bhm::Events::Stats do

  it "supports attributes validation" do
    expect(make_stats).to be_valid
    expect(make_stats.kind).to eq(:stats)

    expect(make_stats('id' => nil)).not_to be_valid
    expect(make_stats('created_at' => nil)).not_to be_valid
    expect(make_stats('created_at' => "foobar")).not_to be_valid

    test_stats = make_stats(
      'id' => nil,
      'created_at' => "foobar",
      'cpu' => nil,
      'memory' => nil,
      'disk' => nil
    )
    test_stats.validate
    expect(test_stats.error_message).to eq("id is missing, cpu is missing, disk is missing, memory is missing, created_at is invalid UNIX timestamp")
  end

  it "has hash representation" do
    ts = Time.now
    expect(make_stats(:created_at => ts.to_i).to_hash).to eq(
      {
        :kind => 'stats',
        :id => 1,
        :cpu => {
          'load' => {

          },
          'stats' => {

          }
        },
        :disk => {...},
        :memory => {...},
        :created_at => ts.to_i
      }
    )
  end

  it "has json representation" do
    stats = make_stats
    expect(stats.to_json).to eq(JSON.dump(stats.to_hash))
  end

  it "has string representation" do
    ts = Time.parse(1320196099)
    stats = make_stats('created_at' => ts)
    expect(stats.to_s).to eq("Stats @ #{ts.utc}")
  end
end
